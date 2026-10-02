import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';
import 'package:tamiltaxi_ui/tamiltaxi_ui.dart';

import '../../state/live_trip.dart';
import '../../state/ride_flow.dart';

/// P-35b Where to (outstation): search any town or place beyond the service area, with each result's distance from
/// the pickup. Before typing, "Popular from here": where riders from this area went (live: from past trips, none
/// built in; mock: demo towns). Pops with the resolved [Place].
class P35bOutstationSearchScreen extends ConsumerStatefulWidget {
  const P35bOutstationSearchScreen({super.key, this.showcase = false});

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  @override
  ConsumerState<P35bOutstationSearchScreen> createState() => _P35bOutstationSearchScreenState();
}

class _P35bOutstationSearchScreenState extends ConsumerState<P35bOutstationSearchScreen> {
  Timer? _debounce;
  int _request = 0;
  String _query = '';

  /// Null while a search is on its way.
  List<Place>? _results;

  /// Why the search failed (shown with Retry instead of the list).
  String? _searchError;

  /// Why the tapped place couldn't be loaded.
  String? _pickError;
  String? _resolving;

  /// Live search starts at [kMinPlaceQuery] letters (each autocomplete request costs); the seed search at 2.
  int get _minLength => ref.read(isLiveApiProvider) ? kMinPlaceQuery : 2;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    _request++;
    setState(() {
      _query = q;
      _results = null;
      _searchError = null;
      _pickError = null;
    });
    if (q.trim().length < _minLength) return;
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(q));
  }

  Future<void> _search(String q) async {
    final id = ++_request;
    setState(() {
      _results = null;
      _searchError = null;
    });
    final pickup = ref.read(rideFlowProvider).pickup.location;
    try {
      final found = await ref.read(placesRepositoryProvider).search(q, origin: pickup, anywhere: true);
      if (!mounted || id != _request) return;
      setState(() => _results = found);
    } on Exception catch (e) {
      if (!mounted || id != _request) return;
      setState(() => _searchError = apiErrorMessage(e));
    }
  }

  Future<void> _pick(Place p) async {
    setState(() {
      _resolving = p.id;
      _pickError = null;
    });
    try {
      final resolved = await ref.read(placesRepositoryProvider).resolve(p);
      if (mounted) context.pop(resolved.copyWith(distanceKm: p.distanceKm));
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _resolving = null;
        _pickError = e is ApiException ? e.message : "Couldn't load that place. ${apiErrorMessage(e)}";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final pickup = ref.watch(rideFlowProvider.select((s) => s.pickup.location));
    final popular = widget.showcase
        ? AsyncData([
            for (final town in Seed.outstationTowns)
              town.copyWith(distanceKm: FareEngine.estimate(Seed.gandhipuram, town).distanceKm),
          ])
        : ref.watch(outstationDestinationsProvider(LatLng(
            double.parse(pickup.latitude.toStringAsFixed(2)),
            double.parse(pickup.longitude.toStringAsFixed(2)),
          )));
    final typed = _query.trim();
    final searching = typed.length >= _minLength;
    final list = searching ? (_results ?? const <Place>[]) : (popular.value ?? const <Place>[]);

    return Scaffold(
      backgroundColor: TtColors.surface,
      appBar: AppBar(
        backgroundColor: TtColors.surface,
        surfaceTintColor: TtColors.surface,
        title: Text('Where to?', style: t.h2),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(TtSpacing.l, 0, TtSpacing.l, TtSpacing.xl),
        children: [
          SearchField(hint: 'Search a town, city or place', showMic: false, autofocus: !widget.showcase, onChanged: _onChanged),
          const SizedBox(height: TtSpacing.l),
          if (_pickError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: TtSpacing.m),
              child: Text(_pickError!, style: t.bodySmall.copyWith(color: TtColors.error)),
            ),
          if (!searching) ...[
            if (typed.isNotEmpty) const SearchMinLengthHint(padding: EdgeInsets.only(bottom: TtSpacing.m)),
            Text('POPULAR FROM HERE', style: t.overline),
            const SizedBox(height: TtSpacing.s),
            if (popular.isLoading)
              for (var i = 0; i < 4; i++) const Padding(padding: EdgeInsets.only(bottom: TtSpacing.s), child: SkeletonBox(height: 56, radius: 12))
            else if (list.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: TtSpacing.l),
                child: Text('Search any town or city. Places people travel to from here will show up as trips are taken.',
                    style: t.bodySmall.copyWith(color: TtColors.navy500)),
              ),
          ] else if (_searchError != null)
            _SearchFailed(message: _searchError!, onRetry: () => _search(_query))
          else if (_results == null)
            for (var i = 0; i < 3; i++) const Padding(padding: EdgeInsets.only(bottom: TtSpacing.s), child: SkeletonBox(height: 56, radius: 12))
          else if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: TtSpacing.l),
              child: Text('No places found for "${_query.trim()}"', style: t.bodySmall.copyWith(color: TtColors.navy500)),
            ),
          for (var i = 0; i < list.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 52),
            LocationRow(
              kind: searching ? LocationRowKind.search : LocationRowKind.landmark,
              icon: searching ? null : Symbols.location_city_rounded,
              title: list[i].name,
              subtitle: list[i].address,
              trailingText: _resolving == list[i].id
                  ? 'Loading…'
                  : list[i].distanceKm == null
                      ? null
                      : '${formatCount(list[i].distanceKm!.round())} km',
              onTap: _resolving == null && !widget.showcase ? () => _pick(list[i]) : null,
            ),
          ],
        ],
      ),
    );
  }
}

/// The search failed: why, and Retry (no skeleton rows under it).
class _SearchFailed extends StatelessWidget {
  const _SearchFailed({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: TtSpacing.s),
      child: Row(
        children: [
          const Icon(Symbols.error_rounded, size: 20, color: TtColors.error, fill: 1),
          const SizedBox(width: TtSpacing.s),
          Expanded(child: Text(message, style: t.bodySmall.copyWith(color: TtColors.error))),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
