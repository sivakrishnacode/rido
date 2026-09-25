import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

import '../../router/routes.dart';
import '../../state/passenger_session.dart';
import 'saved_places_screen.dart';

/// P-23b Add / edit saved place: Home · Work · Other (with a custom name), the place on a small
/// map with "Move pin" (pick from known places), a house / landmark note, Save and Delete.
class P23bSavedPlaceEditorScreen extends ConsumerStatefulWidget {
  const P23bSavedPlaceEditorScreen({super.key, this.placeId, this.showcase = false});

  /// Null to add a new place.
  final String? placeId;

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  @override
  ConsumerState<P23bSavedPlaceEditorScreen> createState() => _P23bSavedPlaceEditorScreenState();
}

class _P23bSavedPlaceEditorScreenState extends ConsumerState<P23bSavedPlaceEditorScreen> {
  SavedPlace? _existing;
  SavedPlaceKind _kind = SavedPlaceKind.other;
  Place? _place;
  final _name = TextEditingController();
  final _note = TextEditingController();
  bool _initialised = false;
  bool _saving = false;

  /// The design frame shows Home being edited.
  String? get _id => widget.placeId ?? (widget.showcase ? Seed.home.id : null);

  @override
  void dispose() {
    _name.dispose();
    _note.dispose();
    super.dispose();
  }

  void _init(PassengerProfile p) {
    if (_initialised) return;
    _initialised = true;
    final id = _id;
    for (final s in p.savedPlaces) {
      if (s.id == id) _existing = s;
    }
    final e = _existing;
    if (e != null) {
      _kind = e.kind;
      _place = e.place;
      if (e.kind == SavedPlaceKind.other) _name.text = e.label;
      if (e.id == Seed.home.id) _note.text = '14, NSR Road, near Bharathi Park';
    } else {
      final taken = p.savedPlaces.map((s) => s.kind).toSet();
      _kind = !taken.contains(SavedPlaceKind.home)
          ? SavedPlaceKind.home
          : !taken.contains(SavedPlaceKind.work)
              ? SavedPlaceKind.work
              : SavedPlaceKind.other;
    }
  }

  String get _label => switch (_kind) {
        SavedPlaceKind.home => 'Home',
        SavedPlaceKind.work => 'Work',
        SavedPlaceKind.other => _name.text.trim(),
      };

  bool get _canSave => _place != null && _label.isNotEmpty && !_saving;

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.savedPlaces);
    }
  }

  Future<void> _pickPlace() async {
    // Pin it on the map (P-09 in pick mode returns the chosen spot).
    final picked = await context.push<Place>(Routes.pinPickOnMap);
    if (picked != null && mounted) setState(() => _place = picked);
  }

  Future<void> _save(PassengerProfile p) async {
    final place = _place;
    if (place == null) return;
    setState(() => _saving = true);
    // Only one Home and one Work: saving a new Home replaces the old one.
    var id = _existing?.id;
    if (id == null && _kind != SavedPlaceKind.other) {
      for (final s in p.savedPlaces) {
        if (s.kind == _kind) id = s.id;
      }
    }
    id ??= 'sp-${DateTime.now().microsecondsSinceEpoch}';
    final label = _label;
    await ref.read(passengerProfileProvider.notifier).saveSavedPlace(
          SavedPlace(id: id, label: label, kind: _kind, place: place),
        );
    if (!mounted) return;
    showRidoSnack(context, '$label saved', success: true);
    _close();
  }

  Future<void> _delete() async {
    final e = _existing;
    if (e == null) return;
    final ok = await showRidoConfirm(
      context,
      title: 'Delete ${e.label}?',
      message: 'You can add it again any time.',
      icon: Symbols.delete_rounded,
      confirmLabel: 'Delete',
      cancelLabel: 'Keep',
      destructive: true,
    );
    if (!ok || !mounted) return;
    await ref.read(passengerProfileProvider.notifier).removeSavedPlace(e.id);
    if (!mounted) return;
    showRidoSnack(context, '${e.label} deleted');
    _close();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final loaded = ref.watch(passengerProfileProvider).value;
    if (loaded != null) _init(loaded);
    final profile = loaded ?? Seed.priya;
    final place = _place;

    return Scaffold(
      backgroundColor: RidoColors.surface,
      appBar: RidoAppBar(
        title: _existing == null ? 'Add saved place' : 'Edit saved place',
        bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider(height: 1)),
        actions: [
          if (_existing != null)
            IconButton(
              tooltip: 'Delete place',
              onPressed: _delete,
              icon: const Icon(Symbols.delete_rounded, color: RidoColors.error),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              children: [
                Text('Save as', style: t.bodyMedium.copyWith(color: RidoColors.navy700)),
                const SizedBox(height: 10),
                ChoiceChips<SavedPlaceKind>(
                  options: SavedPlaceKind.values,
                  labelOf: (k) => switch (k) {
                    SavedPlaceKind.home => 'Home',
                    SavedPlaceKind.work => 'Work',
                    SavedPlaceKind.other => 'Other',
                  },
                  iconOf: savedPlaceIcon,
                  selected: {_kind},
                  onChanged: (k) => setState(() => _kind = k),
                ),
                if (_kind == SavedPlaceKind.other) ...[
                  const SizedBox(height: 16),
                  RidoTextField(
                    label: 'Name this place',
                    hint: 'e.g. Gym, Amma’s house',
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    onChanged: (_) => setState(() {}),
                  ),
                ],
                const SizedBox(height: 20),
                Container(
                  decoration: BoxDecoration(
                    color: RidoColors.surface,
                    borderRadius: RidoRadii.cardRadius,
                    border: Border.all(color: RidoColors.divider),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (place != null)
                        SizedBox(
                          height: 132,
                          child: IgnorePointer(
                            child: RidoMap(
                              key: ValueKey(place.id),
                              center: place.location,
                              zoom: 15.5,
                              drop: place.location,
                              interactive: false,
                              showAttribution: false,
                            ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: place == null
                                  ? Text('Choose the place to save', style: t.body.copyWith(color: RidoColors.navy500))
                                  : Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(place.name, style: t.h2, maxLines: 1, overflow: TextOverflow.ellipsis),
                                        Text(place.address,
                                            style: t.bodySmall.copyWith(color: RidoColors.navy500),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis),
                                      ],
                                    ),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton(
                              onPressed: _pickPlace,
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(48, 44),
                                side: const BorderSide(color: RidoColors.divider, width: 1.5),
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                textStyle: t.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                              ),
                              child: Text(place == null ? 'Choose' : 'Move pin'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                RidoTextField(
                  label: 'House / flat · landmark',
                  hint: 'e.g. 14, NSR Road, near Bharathi Park',
                  controller: _note,
                  textCapitalization: TextCapitalization.sentences,
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: RidoButton(
                label: 'Save place',
                loading: _saving,
                onPressed: _canSave ? () => _save(profile) : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sheet: search the known Coimbatore places and pick one.
class _PlacePicker extends StatefulWidget {
  const _PlacePicker();

  @override
  State<_PlacePicker> createState() => _PlacePickerState();
}

class _PlacePickerState extends State<_PlacePicker> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final q = _q.trim().toLowerCase();
    final places = Seed.places
        .where((p) => q.isEmpty || p.name.toLowerCase().contains(q) || p.address.toLowerCase().contains(q))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Choose a place', style: context.type.h2),
        const SizedBox(height: 12),
        SearchField(hint: 'Search a place in Coimbatore', showMic: false, onChanged: (v) => setState(() => _q = v)),
        const SizedBox(height: 8),
        if (places.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text('No places match "$_q"', style: context.type.bodySmall, textAlign: TextAlign.center),
          ),
        for (final p in places.take(8))
          LocationRow(
            title: p.name,
            subtitle: p.address,
            onTap: () => Navigator.of(context).pop(p),
          ),
      ],
    );
  }
}
