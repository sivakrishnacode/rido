import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

import '../../router/routes.dart';
import '../../state/ride_flow.dart';
import '../states/s04_no_internet_screen.dart';

/// Id prefix of live-API search suggestions (`kApiPlacePrefix` in rido_data, not exported).
const _suggestionPrefix = 'api:';

/// P-08 Search pickup and drop: connected pickup ("Current location, Gandhipuram") and
/// drop fields, live suggestions, "Set on map" and a disabled "Add stop" (Coming soon).
class P08SearchScreen extends ConsumerStatefulWidget {
  const P08SearchScreen({super.key, this.showcase = false});

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  @override
  ConsumerState<P08SearchScreen> createState() => _P08SearchScreenState();
}

class _P08SearchScreenState extends ConsumerState<P08SearchScreen> {
  /// ≥ 300 ms so Google autocomplete is not called on every keystroke.
  static const _debounce = Duration(milliseconds: 300);

  late final TextEditingController _drop = TextEditingController(text: widget.showcase ? 'Brook' : '');
  final TextEditingController _pickup = TextEditingController();
  final FocusNode _pickupFocus = FocusNode();
  final FocusNode _dropFocus = FocusNode();

  /// True while the pickup field is being edited: suggestions then set the pickup.
  bool _editingPickup = false;
  Timer? _timer;
  int _request = 0;
  bool _loading = true;
  bool _offline = false;
  List<Place> _results = const [];

  @override
  void initState() {
    super.initState();
    _search(_drop.text);
    _pickupFocus.addListener(() {
      if (_pickupFocus.hasFocus) {
        setState(() => _editingPickup = true);
        _pickup.clear();
        _search('');
      } else if (_editingPickup) {
        setState(() => _editingPickup = false);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _drop.dispose();
    _pickup.dispose();
    _pickupFocus.dispose();
    _dropFocus.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    _timer?.cancel();
    setState(() => _loading = true);
    _timer = Timer(_debounce, () => _search(q));
  }

  Future<void> _search(String q) async {
    final id = ++_request;
    setState(() {
      _loading = true;
      _offline = false;
    });
    try {
      final results = await ref.read(placesRepositoryProvider).search(q);
      if (!mounted || id != _request) return;
      setState(() {
        final pickupId = ref.read(rideFlowProvider).pickup.id;
        _results = _editingPickup ? results : results.where((p) => p.id != pickupId).toList();
        _loading = false;
      });
    } on OfflineException {
      if (!mounted || id != _request) return;
      setState(() {
        _offline = true;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted || id != _request) return;
      setState(() {
        _results = const [];
        _loading = false;
      });
      showRidoSnack(context, e.message);
    }
  }

  void _clear() {
    _drop.clear();
    _onChanged('');
  }

  Future<void> _choose(Place picked) async {
    // Google suggestions need their details (coordinates) first; seed places come back as is.
    final Place p;
    try {
      p = await ref.read(placesRepositoryProvider).resolve(picked);
    } on OfflineException {
      if (mounted) showRidoSnack(context, "Couldn't load that place. Check your connection and try again.");
      return;
    } on ApiException catch (e) {
      if (mounted) showRidoSnack(context, e.message);
      return;
    }
    if (!mounted) return;
    if (_editingPickup) {
      ref.read(rideFlowProvider.notifier).setPickup(p);
      setState(() => _editingPickup = false);
      _dropFocus.requestFocus();
      _search(_drop.text);
      return;
    }
    ref.read(rideFlowProvider.notifier).setDrop(p);
    context.push(Routes.chooseVehicle);
  }

  void _useCurrentLocation() {
    final here = ref.read(placesRepositoryProvider).currentLocation;
    ref.read(rideFlowProvider.notifier).setPickup(here);
    _pickupFocus.unfocus();
    _dropFocus.requestFocus();
    showRidoSnack(context, 'Pickup set to your current location');
  }

  IconData? _iconFor(Place p) => switch (p.id) {
    'brookefields' || 'prozone' => Symbols.storefront_rounded,
    'airport' => Symbols.flight_rounded,
    'junction' => Symbols.train_rounded,
    'psg-tech' => Symbols.school_rounded,
    'tidel-park' => Symbols.apartment_rounded,
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final pickup = ref.watch(rideFlowProvider.select((s) => s.pickup));
    final pickupLabel = pickup.id == Seed.gandhipuram.id ? 'Current location, Gandhipuram' : pickup.name;
    return Scaffold(
      backgroundColor: RidoColors.surface,
      appBar: const RidoAppBar(title: 'Plan your ride'),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(RidoSpacing.l, RidoSpacing.xs, RidoSpacing.l, 0),
              child: _ConnectedFields(
                pickup: _PickupField(
                  label: pickupLabel,
                  controller: _pickup,
                  focusNode: _pickupFocus,
                  editing: _editingPickup,
                  onChanged: _onChanged,
                  onLocate: _useCurrentLocation,
                ),
                drop: TextField(
                  controller: _drop,
                  focusNode: _dropFocus,
                  autofocus: true,
                  onChanged: _onChanged,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) {
                    if (_results.isNotEmpty) _choose(_results.first);
                  },
                  style: t.body,
                  decoration: InputDecoration(
                    hintText: 'Where to?',
                    contentPadding: const EdgeInsets.symmetric(horizontal: RidoSpacing.l, vertical: RidoSpacing.l),
                    suffixIcon: ValueListenableBuilder(
                      valueListenable: _drop,
                      builder: (context, v, _) => v.text.isEmpty
                          ? const SizedBox.shrink()
                          : IconButton(
                              tooltip: 'Clear',
                              onPressed: _clear,
                              icon: const Icon(Symbols.cancel_rounded, color: RidoColors.navy500),
                            ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(RidoSpacing.l, RidoSpacing.l, RidoSpacing.l, RidoSpacing.m),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _PillButton(
                      icon: Symbols.map_rounded,
                      label: _editingPickup ? 'Set pickup on map' : 'Set on map',
                      onTap: () => context.push(_editingPickup ? Routes.pinPickupOnMap : Routes.pinOnMap),
                    ),
                    const SizedBox(width: RidoSpacing.s),
                    Tooltip(
                      message: 'Coming soon',
                      triggerMode: TooltipTriggerMode.tap,
                      child: Semantics(
                        enabled: false,
                        label: 'Add stop, coming soon',
                        child: const _PillButton(icon: Symbols.add_rounded, label: 'Add stop'),
                      ),
                    ),
                    const SizedBox(width: RidoSpacing.s),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: RidoSpacing.m, vertical: 6),
                      decoration: const BoxDecoration(color: RidoColors.inputBg, borderRadius: RidoRadii.pillRadius),
                      child: Text(
                        'Coming soon',
                        style: t.caption.copyWith(color: RidoColors.navy700, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1, thickness: 1),
            Expanded(child: _resultsView()),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(RidoSpacing.l, RidoSpacing.m, RidoSpacing.l, RidoSpacing.m),
              child: Row(
                children: [
                  const Icon(Symbols.info_rounded, size: 18, color: RidoColors.navy500),
                  const SizedBox(width: RidoSpacing.s),
                  Expanded(
                    child: Text(
                      'Can\'t find it? Use "Set on map" to drop a pin.',
                      style: t.bodySmall.copyWith(color: RidoColors.navy500),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resultsView() {
    final t = context.type;
    if (_offline) return S04NoInternetView(onRetry: () => _search(_drop.text));
    if (_loading) {
      return SkeletonShimmer(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: RidoSpacing.l, vertical: RidoSpacing.s),
          children: [
            for (var i = 0; i < 3; i++)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: RidoSpacing.m),
                child: Row(
                  children: [
                    SkeletonBox(width: 40, height: 40, circle: true),
                    SizedBox(width: RidoSpacing.m),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FractionallySizedBox(widthFactor: 0.6, child: SkeletonBox(height: 12)),
                          SizedBox(height: RidoSpacing.s),
                          FractionallySizedBox(widthFactor: 0.4, child: SkeletonBox(height: 10)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    }
    if (_results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(RidoSpacing.xl),
        child: Text(
          'No places found for "${_drop.text.trim()}"',
          style: t.body.copyWith(color: RidoColors.navy500),
          textAlign: TextAlign.center,
        ),
      );
    }
    final pickup = ref.read(rideFlowProvider).pickup;
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: _results.length,
      separatorBuilder: (_, _) => const Divider(height: 1, indent: 68),
      itemBuilder: (context, i) {
        final p = _results[i];
        final icon = _iconFor(p);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: RidoSpacing.l),
          child: LocationRow(
            kind: icon == Symbols.storefront_rounded ? LocationRowKind.landmark : LocationRowKind.search,
            icon: icon,
            title: p.name,
            subtitle: p.address,
            // Search suggestions only get coordinates when picked (Place Details), so no distance for them.
            trailingText: p.id.startsWith(_suggestionPrefix) ? null : formatKm(FareEngine.estimate(pickup, p).distanceKm),
            onTap: () => _choose(p),
          ),
        );
      },
    );
  }
}

/// Dot → dotted line → pin on the left, the two fields on the right.
class _ConnectedFields extends StatelessWidget {
  const _ConnectedFields({required this.pickup, required this.drop});
  final Widget pickup;
  final Widget drop;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const SizedBox(
        width: 32,
        child: Column(
          children: [
            PickupDot(size: 12),
            SizedBox(height: RidoSpacing.xs),
            _Dots(),
            SizedBox(height: RidoSpacing.m),
            DropPin(size: 22),
          ],
        ),
      ),
      const SizedBox(width: RidoSpacing.s),
      Expanded(
        child: Column(
          children: [
            pickup,
            const SizedBox(height: RidoSpacing.m),
            drop,
          ],
        ),
      ),
    ],
  );
}

class _Dots extends StatelessWidget {
  const _Dots();

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var i = 0; i < 6; i++)
        Container(width: 2, height: 3, margin: const EdgeInsets.symmetric(vertical: 1.5), color: RidoColors.navy500),
    ],
  );
}

/// Pickup field: shows the chosen pickup; tap to search for another one.
class _PickupField extends StatelessWidget {
  const _PickupField({
    required this.label,
    required this.controller,
    required this.focusNode,
    required this.editing,
    required this.onChanged,
    required this.onLocate,
  });
  final String label;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool editing;
  final ValueChanged<String> onChanged;
  final VoidCallback onLocate;

  @override
  Widget build(BuildContext context) => TextField(
    key: const ValueKey('pickup-field'),
    controller: controller,
    focusNode: focusNode,
    onChanged: onChanged,
    textInputAction: TextInputAction.search,
    style: context.type.body,
    decoration: InputDecoration(
      // When not editing, the current pickup shows as the hint (reads like a value).
      hintText: editing ? 'Search pickup location' : label,
      hintStyle: context.type.body.copyWith(color: editing ? RidoColors.navy500 : RidoColors.navy900),
      contentPadding: const EdgeInsets.symmetric(horizontal: RidoSpacing.l, vertical: RidoSpacing.l),
      suffixIcon: IconButton(
        tooltip: 'Use current location',
        onPressed: onLocate,
        icon: const Icon(Symbols.my_location_rounded, color: RidoColors.navy500),
      ),
    ),
  );
}

/// Outlined pill ("Set on map"). Disabled look when [onTap] is null.
class _PillButton extends StatelessWidget {
  const _PillButton({required this.icon, required this.label, this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final fg = enabled ? RidoColors.navy900 : RidoColors.navy300;
    return Material(
      color: RidoColors.surface,
      shape: StadiumBorder(side: BorderSide(color: enabled ? RidoColors.divider : RidoColors.inputBg)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: RidoSpacing.l),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: enabled ? RidoColors.coral600 : RidoColors.navy300),
              const SizedBox(width: RidoSpacing.s),
              Text(label, style: context.type.bodySemibold.copyWith(color: fg)),
            ],
          ),
        ),
      ),
    );
  }
}
