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
  String _query = '';
  List<Place>? _results;
  String? _error;
  String? _resolving;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String q) {
    setState(() => _query = q);
    _debounce?.cancel();
    if (q.trim().length < 2) {
      setState(() => _results = null);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(q));
  }

  Future<void> _search(String q) async {
    final pickup = ref.read(rideFlowProvider).pickup.location;
    try {
      final found = await ref.read(placesRepositoryProvider).search(q, origin: pickup, anywhere: true);
      if (!mounted || q != _query) return;
      setState(() {
        _results = found;
        _error = null;
      });
    } on Exception catch (e) {
      if (mounted) setState(() => _error = apiErrorMessage(e));
    }
  }

  Future<void> _pick(Place p) async {
    setState(() => _resolving = p.id);
    try {
      final resolved = await ref.read(placesRepositoryProvider).resolve(p);
      if (mounted) context.pop(resolved.copyWith(distanceKm: p.distanceKm));
    } on Exception catch (e) {
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
    final searching = _query.trim().length >= 2;
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
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: TtSpacing.m),
              child: Text(_error!, style: t.bodySmall.copyWith(color: TtColors.error)),
            ),
          if (!searching) ...[
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
          ] else if (_results == null)
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
