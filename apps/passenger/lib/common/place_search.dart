import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';
import 'package:tamiltaxi_ui/tamiltaxi_ui.dart';

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
  bool anywhere = false,
}) => showTtSheet<PlacePick>(
  context,
  builder: (_) => _PlaceSearchSheet(title: title, current: current, offerMap: offerMap, anywhere: anywhere),
);

class _PlaceSearchSheet extends ConsumerStatefulWidget {
  const _PlaceSearchSheet({required this.title, this.current, required this.offerMap, this.anywhere = false});

  final String title;
  final Place? current;
  final bool offerMap;

  /// Other towns too (goods to another town): no service-area restriction.
  final bool anywhere;

  @override
  ConsumerState<_PlaceSearchSheet> createState() => _PlaceSearchSheetState();
}

class _PlaceSearchSheetState extends ConsumerState<_PlaceSearchSheet> {
  /// ~350 ms so Google autocomplete is not called on every keystroke.
  static const _debounce = Duration(milliseconds: 350);

  Timer? _timer;
  int _request = 0;
  String _query = '';
  bool _loading = true;
  String? _error;
  String? _resolving;
  List<Place> _results = const [];

  /// What the empty search lists (recent places), shown again while the text is too short to search.
  List<Place> _recents = const [];

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

  /// Live text under [kMinPlaceQuery] characters (but not empty): too short to search (live search starts there).
  bool _isShort(String q) => _live && q.trim().isNotEmpty && q.trim().length < kMinPlaceQuery;

  void _onChanged(String q) {
    _timer?.cancel();
    final empty = q.trim().isEmpty;
    if (empty || _isShort(q)) {
      // Nothing to search yet: the recent places again (with the hint while typing).
      _request++;
      setState(() {
        _query = q;
        _loading = false;
        _error = null;
        _results = _recents;
      });
      return;
    }
    // An answer still on its way is for older text: drop it.
    _request++;
    setState(() {
      _query = q;
      _loading = true;
    });
    _timer = Timer(_debounce, () => _search(q));
  }

  Future<void> _search(String q) async {
    final id = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await ref.read(placesRepositoryProvider).search(q, anywhere: widget.anywhere);
      if (!mounted || id != _request) return;
      setState(() {
        if (q.trim().isEmpty) _recents = results;
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
        // The API's own words when it answered (e.g. the place is no longer listed).
        _error = e is ApiException ? e.message : "Couldn't load that place. ${apiErrorMessage(e)}";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final q = _query.trim();
    final tooShort = _isShort(_query);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.title, style: t.h2),
        const SizedBox(height: 12),
        SearchField(
          hint: widget.anywhere ? 'Search a town, city or place' : 'Search for a place',
          showMic: false,
          autofocus: true,
          onChanged: _onChanged,
        ),
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
                const Icon(Symbols.error_rounded, size: 20, color: TtColors.error, fill: 1),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_error!, style: t.bodySmall.copyWith(color: TtColors.error)),
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
        else if (tooShort && _results.isEmpty)
          const SearchMinLengthHint()
        else if (_results.isEmpty && _error == null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              q.isEmpty ? 'Type a place, area or landmark' : 'No places match "$q"',
              style: t.bodySmall,
              textAlign: TextAlign.center,
            ),
          )
        else ...[
          if (tooShort) const SearchMinLengthHint(),
          for (final p in _results.take(8))
            LocationRow(
              kind: q.isEmpty || tooShort ? LocationRowKind.recent : LocationRowKind.search,
              title: p.name,
              subtitle: p.address,
              trailingText: _resolving == p.id
                  ? '…'
                  : (widget.current != null && p.id == widget.current!.id ? '✓' : null),
              onTap: () => _pick(p),
            ),
        ],
      ],
    );
  }
}
