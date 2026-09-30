import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart' show Distance, LengthUnit;
import 'package:tamiltaxi_data/tamiltaxi_data.dart';
import 'package:tamiltaxi_ui/tamiltaxi_ui.dart';

import '../../../state/booking_prefs.dart';
import '../../../state/driver_session.dart';
import '../../../state/live_helpers.dart';

/// Go To (trips towards a place) or Stay In (trips that stay inside an area), like Rapido's. One at a time; the server
/// filters requests (booking preferences) and switches them off after 2 h / 12 h.
enum TripDirection {
  goTo('Go To', Symbols.near_me_rounded),
  stayIn('Stay In', Symbols.adjust_rounded);

  const TripDirection(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// Stay In radii offered (km).
const kStayInRadii = [3.0, 5.0, 8.0, 12.0];

String _radius(double km) => '${km == km.roundToDouble() ? km.toInt() : km} km';

/// Where the driver is now (latest GPS fix), if known.
LatLng? _here(WidgetRef ref) {
  final session = ref.read(driverSessionProvider.notifier);
  return session.position ?? session.vehicle.value?.position;
}

double _km(LatLng a, LatLng b) => const Distance().as(LengthUnit.Meter, a, b) / 1000;

/// What is on for [direction] in [prefs] (null when off, or its time is up), as a place.
SavedArea? _activeArea(BookingPrefs prefs, TripDirection direction, DateTime now) {
  bool running(DateTime? until) => until == null || until.isAfter(now);
  final goTo = prefs.goTo;
  final stayIn = prefs.stayIn;
  return switch (direction) {
    TripDirection.goTo when goTo != null && running(goTo.until) => SavedArea(name: goTo.name, location: goTo.location),
    TripDirection.stayIn when stayIn != null && running(stayIn.until) =>
      SavedArea(name: stayIn.name, location: stayIn.location),
    _ => null,
  };
}

/// Home, online: "Go To" / "Stay In" buttons, or the one that is on ("Going to Home · till 4:30 PM", Change, Off).
class DirectionRow extends ConsumerWidget {
  const DirectionRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(bookingPrefsProvider).value;
    if (prefs == null) return const SizedBox.shrink();
    final now = DateTime.now();
    final goTo = _activeArea(prefs, TripDirection.goTo, now);
    final stayIn = _activeArea(prefs, TripDirection.stayIn, now);
    if (goTo == null && stayIn == null) {
      return Row(children: [
        for (final d in TripDirection.values) ...[
          if (d != TripDirection.values.first) const SizedBox(width: TtSpacing.s),
          Expanded(child: _DirectionButton(direction: d, onTap: () => showDirectionSheet(context, initial: d))),
        ],
      ]);
    }
    final isGoTo = goTo != null;
    final until = isGoTo ? prefs.goTo!.until : prefs.stayIn!.until;
    return _DirectionStrip(
      direction: isGoTo ? TripDirection.goTo : TripDirection.stayIn,
      title: isGoTo ? 'Going to ${goTo.name}' : 'Staying in ${stayIn!.name}',
      detail: [
        isGoTo ? 'Only trips towards it' : 'Only trips within ${_radius(prefs.stayIn!.radiusKm)}',
        if (until != null) 'till ${formatTime(until)}',
      ].join(' · '),
      onChange: () => showDirectionSheet(context),
      onOff: () async {
        try {
          await ref.read(bookingPrefsProvider.notifier).change((p) => p.goingTo(null));
          if (context.mounted) showTtSnack(context, "${isGoTo ? 'Go To' : 'Stay In'} is off. You get requests from anywhere");
        } on Exception catch (e) {
          if (context.mounted) showTtSnack(context, userMessage(e));
        }
      },
    );
  }
}

class _DirectionButton extends StatelessWidget {
  const _DirectionButton({required this.direction, required this.onTap});
  final TripDirection direction;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: TtColors.inputBg,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 44,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(direction.icon, size: 20, color: TtColors.navy900, fill: 1),
              const SizedBox(width: TtSpacing.s),
              Text(direction.label, style: context.type.bodySemibold),
            ]),
          ),
        ),
      );
}

/// "Going to Home / Only trips towards it · till 4:30 PM   Change  ✕", tinted by direction.
class _DirectionStrip extends StatelessWidget {
  const _DirectionStrip({
    required this.direction,
    required this.title,
    required this.detail,
    required this.onChange,
    required this.onOff,
  });
  final TripDirection direction;
  final String title;
  final String detail;
  final VoidCallback onChange;
  final VoidCallback onOff;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final goTo = direction == TripDirection.goTo;
    final fg = goTo ? TtColors.successText : TtColors.navy900;
    return Container(
      padding: const EdgeInsets.fromLTRB(TtSpacing.m, TtSpacing.s, TtSpacing.xs, TtSpacing.s),
      decoration: BoxDecoration(
        color: goTo ? TtColors.successTint : TtColors.infoTint,
        borderRadius: TtRadii.cardRadius,
      ),
      child: Row(children: [
        Icon(direction.icon, color: fg, fill: 1, size: 24),
        const SizedBox(width: TtSpacing.m),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: t.bodySemibold.copyWith(color: fg), maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(detail, style: t.bodySmall.copyWith(color: fg), maxLines: 2, overflow: TextOverflow.ellipsis),
          ]),
        ),
        TextButton(onPressed: onChange, child: const Text('Change')),
        IconButton(
          tooltip: 'Turn ${direction.label} off',
          onPressed: onOff,
          icon: Icon(Symbols.close_rounded, color: fg),
        ),
      ]),
    );
  }
}

/// The Go To / Stay In sheet: pick a saved area (or add one), the Stay In radius, and turn it on, change or off.
Future<void> showDirectionSheet(BuildContext context, {TripDirection? initial}) =>
    showTtSheet<void>(context, builder: (_) => _DirectionSheet(initial: initial));

class _DirectionSheet extends ConsumerStatefulWidget {
  const _DirectionSheet({this.initial});
  final TripDirection? initial;

  @override
  ConsumerState<_DirectionSheet> createState() => _DirectionSheetState();
}

class _DirectionSheetState extends ConsumerState<_DirectionSheet> {
  late TripDirection _mode;
  SavedArea? _picked;
  double _radiusKm = 5;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(bookingPrefsProvider).value ?? const BookingPrefs();
    final now = DateTime.now();
    _mode = widget.initial ??
        (_activeArea(prefs, TripDirection.stayIn, now) != null ? TripDirection.stayIn : TripDirection.goTo);
    _startOn(prefs);
  }

  /// Picks what is on in [_mode] (its place and radius), if anything.
  void _startOn(BookingPrefs prefs) {
    _picked = _activeArea(prefs, _mode, DateTime.now());
    if (_mode == TripDirection.stayIn && prefs.stayIn != null) _radiusKm = prefs.stayIn!.radiusKm;
  }

  BookingPrefsController get _prefs => ref.read(bookingPrefsProvider.notifier);

  Future<void> _addArea() async {
    final area = await showAddAreaSheet(context);
    if (area == null || !mounted) return;
    try {
      await _prefs.saveArea(area);
      if (mounted) setState(() => _picked = area);
    } on Exception catch (e) {
      if (mounted) showTtSnack(context, userMessage(e));
    }
  }

  Future<void> _remove(SavedArea area) async {
    try {
      await _prefs.removeArea(area);
      if (mounted && _picked != null && _picked!.isAt(area.location)) setState(() => _picked = null);
    } on Exception catch (e) {
      if (mounted) showTtSnack(context, userMessage(e));
    }
  }

  Future<void> _apply({required bool on}) async {
    final area = _picked;
    if (on && area == null) return;
    setState(() => _busy = true);
    try {
      await _prefs.change((p) => !on
          ? p.goingTo(null)
          : _mode == TripDirection.goTo
              ? p.goingTo(area)
              : p.stayingIn(area, radiusKm: _radiusKm));
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showTtSnack(context, userMessage(e));
      return;
    }
    if (!mounted) return;
    final saved = ref.read(bookingPrefsProvider).value;
    final until = _mode == TripDirection.goTo ? saved?.goTo?.until : saved?.stayIn?.until;
    showTtSnack(
      context,
      on
          ? '${_mode.label} is on${until == null ? '' : ' till ${formatTime(until)}'}. Only trips that fit reach you'
          : '${_mode.label} is off. You get requests from anywhere',
      success: on,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final prefs = ref.watch(bookingPrefsProvider).value ?? const BookingPrefs();
    final now = DateTime.now();
    final active = _activeArea(prefs, _mode, now);
    final other = _activeArea(prefs, _mode == TripDirection.goTo ? TripDirection.stayIn : TripDirection.goTo, now);
    // The place that is on stays listed even if it isn't saved (set from an older app).
    final areas = [
      if (active != null && !prefs.areas.any((a) => a.isAt(active.location))) active,
      ...prefs.areas,
    ];
    final here = _here(ref);
    final picked = _picked;
    final unchanged = active != null &&
        picked != null &&
        active.isAt(picked.location) &&
        (_mode == TripDirection.goTo || prefs.stayIn?.radiusKm == _radiusKm);

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Text('Where do you want trips?', style: t.h2),
      const SizedBox(height: TtSpacing.m),
      TtSegmented<TripDirection>(
        options: TripDirection.values,
        labelOf: (d) => d.label,
        selected: _mode,
        onChanged: (d) => setState(() {
          _mode = d;
          _startOn(prefs);
        }),
      ),
      const SizedBox(height: TtSpacing.m),
      Text(
        _mode == TripDirection.goTo
            ? 'Heading home or to your stand? Only trips that end near it, or take you at least halfway there. '
                'On for 2 hours.'
            : 'Want to work in one area? Only trips that start and end inside it. On for 12 hours.',
        style: t.bodySmall.copyWith(color: TtColors.navy700),
      ),
      const SizedBox(height: TtSpacing.l),
      Text('YOUR AREAS', style: t.overline),
      const SizedBox(height: TtSpacing.xs),
      if (areas.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: TtSpacing.s),
          child: Text('Save a place you often go to, like Home or your stand.', style: t.bodySmall),
        ),
      for (final a in areas)
        _AreaTile(
          key: ValueKey('area-${a.name}-${a.location.latitude},${a.location.longitude}'),
          area: a,
          selected: picked != null && picked.isAt(a.location),
          isOn: active != null && active.isAt(a.location),
          kmAway: here == null ? null : _km(here, a.location),
          onTap: () => setState(() => _picked = a),
          onRemove: prefs.areas.contains(a) ? () => _remove(a) : null,
        ),
      if (prefs.areas.length < BookingPrefs.maxAreas)
        Align(
          alignment: Alignment.centerLeft,
          child: TtButton.text(label: 'Add area', icon: Symbols.add_location_alt_rounded, onPressed: _addArea),
        ),
      if (_mode == TripDirection.stayIn) ...[
        const SizedBox(height: TtSpacing.s),
        Text('HOW FAR AROUND IT', style: t.overline),
        const SizedBox(height: TtSpacing.s),
        ChoiceChips<double>(
          options: kStayInRadii,
          labelOf: _radius,
          selected: {_radiusKm},
          onChanged: (km) => setState(() => _radiusKm = km),
        ),
      ],
      const SizedBox(height: TtSpacing.l),
      if (other != null && picked != null && !unchanged)
        Padding(
          padding: const EdgeInsets.only(bottom: TtSpacing.s),
          child: Text(
            '${_mode == TripDirection.goTo ? 'Stay In' : 'Go To'} (${other.name}) turns off.',
            style: t.caption.copyWith(color: TtColors.navy500),
            textAlign: TextAlign.center,
          ),
        ),
      TtButton(
        label: active == null ? 'Turn on ${_mode.label}' : 'Update ${_mode.label}',
        icon: _mode.icon,
        loading: _busy,
        onPressed: picked == null || unchanged ? null : () => _apply(on: true),
      ),
      if (active != null)
        TtButton(
          label: 'Turn ${_mode.label} off',
          variant: TtButtonVariant.dangerText,
          onPressed: _busy ? null : () => _apply(on: false),
        ),
    ]);
  }
}

/// A saved area: name, how far it is, selected ring; ✕ removes it.
class _AreaTile extends StatelessWidget {
  const _AreaTile({
    super.key,
    required this.area,
    required this.selected,
    required this.isOn,
    required this.kmAway,
    required this.onTap,
    required this.onRemove,
  });
  final SavedArea area;
  final bool selected;
  final bool isOn;
  final double? kmAway;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final isHome = area.name.toLowerCase() == 'home';
    final subtitle = [if (isOn) 'On now', if (kmAway != null) '${formatKm(kmAway!)} from you'].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: TtSpacing.s),
      child: Semantics(
        selected: selected,
        button: true,
        child: Material(
          color: selected ? TtColors.coral50 : TtColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: TtRadii.cardRadius,
            side: BorderSide(color: selected ? TtColors.coral600 : TtColors.divider, width: selected ? 1.5 : 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(TtSpacing.m, TtSpacing.s, TtSpacing.xs, TtSpacing.s),
              child: Row(children: [
                Icon(isHome ? Symbols.home_rounded : Symbols.location_on_rounded,
                    color: selected ? TtColors.coral600 : TtColors.navy700, fill: 1),
                const SizedBox(width: TtSpacing.m),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(area.name, style: t.bodySemibold, maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (subtitle.isNotEmpty)
                      Text(subtitle, style: t.bodySmall.copyWith(color: isOn ? TtColors.successText : TtColors.navy500)),
                  ]),
                ),
                Icon(
                  selected ? Symbols.radio_button_checked_rounded : Symbols.radio_button_unchecked_rounded,
                  color: selected ? TtColors.coral600 : TtColors.navy300,
                ),
                if (onRemove != null)
                  IconButton(
                    tooltip: 'Remove ${area.name}',
                    onPressed: onRemove,
                    icon: const Icon(Symbols.delete_rounded, color: TtColors.navy500, size: 20),
                  )
                else
                  const SizedBox(width: TtSpacing.s),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Add an area": Home where the driver is, where they are now, or a searched place. Returns the area to save.
Future<SavedArea?> showAddAreaSheet(BuildContext context) =>
    showTtSheet<SavedArea>(context, builder: (_) => const _AddAreaSheet());

class _AddAreaSheet extends ConsumerStatefulWidget {
  const _AddAreaSheet();

  @override
  ConsumerState<_AddAreaSheet> createState() => _AddAreaSheetState();
}

class _AddAreaSheetState extends ConsumerState<_AddAreaSheet> {
  /// ≥ 300 ms so Google autocomplete is not called on every keystroke.
  static const _debounce = Duration(milliseconds: 300);

  /// Live API: autocomplete starts at 3 characters (tech doc cost rules).
  static const _minLiveQuery = 3;

  Timer? _timer;
  int _request = 0;
  String _query = '';
  bool _loading = false;
  String? _error;

  /// The row being resolved ('home', 'here' or a place id).
  String? _resolving;
  List<Place> _results = const [];

  bool get _live => ref.read(isLiveApiProvider);

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _onChanged(String q) {
    _timer?.cancel();
    final trimmed = q.trim();
    setState(() {
      _query = q;
      _error = null;
      _results = const [];
      _loading = trimmed.isNotEmpty && !(_live && trimmed.length < _minLiveQuery);
    });
    if (_loading) _timer = Timer(_debounce, () => _search(trimmed));
  }

  Future<void> _search(String q) async {
    final id = ++_request;
    try {
      final results = await ref.read(placesRepositoryProvider).search(q, origin: _here(ref));
      if (!mounted || id != _request) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || id != _request) return;
      setState(() {
        _error = userMessage(e);
        _loading = false;
      });
    }
  }

  /// Where the driver is, or a snack when the GPS hasn't answered yet.
  LatLng? _hereOrSay() {
    final here = _here(ref);
    if (here == null) showTtSnack(context, 'Waiting for your location. Try again in a moment');
    return here;
  }

  Future<void> _done(String key, Future<SavedArea> Function() build) async {
    if (_resolving != null) return;
    setState(() {
      _resolving = key;
      _error = null;
    });
    try {
      final area = await build();
      if (mounted) Navigator.of(context).pop(area);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _resolving = null;
        _error = "Couldn't add that place. ${userMessage(e)}";
      });
    }
  }

  void _home() {
    final here = _hereOrSay();
    if (here != null) _done('home', () async => SavedArea(name: 'Home', location: here));
  }

  void _whereIAm() {
    final here = _hereOrSay();
    if (here == null) return;
    _done('here', () async {
      final place = await ref.read(placesRepositoryProvider).reverseGeocode(here);
      return SavedArea(name: place.name.isEmpty ? 'My area' : place.name, location: here);
    });
  }

  void _pick(Place p) => _done(p.id, () async {
        final resolved = await ref.read(placesRepositoryProvider).resolve(p);
        return SavedArea(name: resolved.name, location: resolved.location);
      });

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final q = _query.trim();
    final tooShort = _live && q.isNotEmpty && q.length < _minLiveQuery;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Text('Add an area', style: t.h2),
      const SizedBox(height: TtSpacing.m),
      SearchField(hint: 'Search an area or landmark', showMic: false, onChanged: _onChanged),
      const SizedBox(height: TtSpacing.s),
      if (q.isEmpty) ...[
        LocationRow(
          kind: LocationRowKind.saved,
          icon: Symbols.home_rounded,
          title: 'Set Home to where I am',
          subtitle: 'For Go To at the end of the day',
          trailingText: _resolving == 'home' ? '…' : null,
          onTap: _home,
        ),
        LocationRow(
          kind: LocationRowKind.saved,
          icon: Symbols.my_location_rounded,
          title: 'Use where I am',
          subtitle: 'Save this area by its name',
          trailingText: _resolving == 'here' ? '…' : null,
          onTap: _whereIAm,
        ),
      ],
      if (_error != null)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: TtSpacing.m),
          child: Text(_error!, style: t.bodySmall.copyWith(color: TtColors.error)),
        ),
      if (_loading)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: TtSpacing.xl),
          child: Center(child: SizedBox.square(dimension: 28, child: CircularProgressIndicator(strokeWidth: 3))),
        )
      else if (tooShort)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: TtSpacing.xl),
          child: Text('Keep typing to search', style: t.bodySmall, textAlign: TextAlign.center),
        )
      else if (q.isNotEmpty && _results.isEmpty && _error == null)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: TtSpacing.xl),
          child: Text('No places match "$q"', style: t.bodySmall, textAlign: TextAlign.center),
        )
      else
        for (final p in _results.take(8))
          LocationRow(
            title: p.name,
            subtitle: p.address,
            trailingText: _resolving == p.id ? '…' : null,
            onTap: () => _pick(p),
          ),
    ]);
  }
}
