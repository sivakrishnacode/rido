import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

import '../state/live_trip.dart';

/// What the passenger picked in [showPlaceSearchSheet]: a resolved [place], or "Set on map".
class PlacePick {
  const PlacePick.place(Place this.place) : onMap = false;
  const PlacePick.onMap() : place = null, onMap = true;

  final Place? place;
  final bool onMap;
}

/// Sheet that searches places through [PlacesRepository.search] (Google autocomplete via the API when live,
/// seed places in mock mode) and returns the tapped one after [PlacesRepository.resolve] fetched its
/// coordinates. [offerMap] adds a "Set on map" row.
Future<PlacePick?> showPlaceSearchSheet(
  BuildContext context, {
  required String title,
  Place? current,
  bool offerMap = false,
}) => showRidoSheet<PlacePick>(
  context,
  builder: (_) => _PlaceSearchSheet(title: title, current: current, offerMap: offerMap),
);

class _PlaceSearchSheet extends ConsumerStatefulWidget {
  const _PlaceSearchSheet({required this.title, this.current, required this.offerMap});

  final String title;
  final Place? current;
  final bool offerMap;

  @override
  ConsumerState<_PlaceSearchSheet> createState() => _PlaceSearchSheetState();
}

class _PlaceSearchSheetState extends ConsumerState<_PlaceSearchSheet> {
  /// ≥ 300 ms so Google autocomplete is not called on every keystroke.
  static const _debounce = Duration(milliseconds: 300);

  /// Live API: autocomplete starts at 3 characters (tech doc cost rules).
  static const _minLiveQuery = 3;

  Timer? _timer;
  int _request = 0;
  String _query = '';
  bool _loading = true;
  String? _error;
  String? _resolving;
  List<Place> _results = const [];

  bool get _live => ref.read(isLiveApiProvider);

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _onChanged(String q) {
    _timer?.cancel();
    setState(() => _query = q);
    final trimmed = q.trim();
    if (_live && trimmed.isNotEmpty && trimmed.length < _minLiveQuery) {
      setState(() {
        _loading = false;
        _results = const [];
      });
      return;
    }
    setState(() => _loading = true);
    _timer = Timer(_debounce, () => _search(q));
  }

  Future<void> _search(String q) async {
    final id = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await ref.read(placesRepositoryProvider).search(q);
      if (!mounted || id != _request) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || id != _request) return;
      setState(() {
        _error = apiErrorMessage(e);
        _loading = false;
      });
    }
  }

  Future<void> _pick(Place p) async {
    if (_resolving != null) return;
    setState(() {
      _resolving = p.id;
      _error = null;
    });
    try {
      final resolved = await ref.read(placesRepositoryProvider).resolve(p);
      if (mounted) Navigator.of(context).pop(PlacePick.place(resolved));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _resolving = null;
        _error = "Couldn't load that place. ${apiErrorMessage(e)}";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final q = _query.trim();
    final tooShort = _live && q.isNotEmpty && q.length < _minLiveQuery;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.title, style: t.h2),
        const SizedBox(height: 12),
        SearchField(hint: 'Search a place in Coimbatore', showMic: false, autofocus: true, onChanged: _onChanged),
        const SizedBox(height: 8),
        if (widget.offerMap)
          LocationRow(
            icon: Symbols.map_rounded,
            title: 'Set on map',
            subtitle: 'Move the map under a pin',
            onTap: () => Navigator.of(context).pop(const PlacePick.onMap()),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                const Icon(Symbols.error_rounded, size: 20, color: RidoColors.error, fill: 1),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_error!, style: t.bodySmall.copyWith(color: RidoColors.error)),
                ),
                TextButton(onPressed: () => _search(_query), child: const Text('Retry')),
              ],
            ),
          ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: SizedBox.square(dimension: 28, child: CircularProgressIndicator(strokeWidth: 3))),
          )
        else if (tooShort)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text('Keep typing to search', style: t.bodySmall, textAlign: TextAlign.center),
          )
        else if (_results.isEmpty && _error == null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              q.isEmpty ? 'Type a place, area or landmark' : 'No places match "$q"',
              style: t.bodySmall,
              textAlign: TextAlign.center,
            ),
          )
        else
          for (final p in _results.take(8))
            LocationRow(
              kind: q.isEmpty ? LocationRowKind.recent : LocationRowKind.search,
              title: p.name,
              subtitle: p.address,
              trailingText: _resolving == p.id
                  ? '…'
                  : (widget.current != null && p.id == widget.current!.id ? '✓' : null),
              onTap: () => _pick(p),
            ),
      ],
    );
  }
}
