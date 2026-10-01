import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';
import 'package:tamiltaxi_ui/tamiltaxi_ui.dart';

import '../../common/add_extra_card.dart';
import '../../common/map_insets.dart';
import '../../common/trip_routes.dart';
import '../../router/routes.dart';
import '../../state/nearby_vehicles.dart';
import '../../state/ride_flow.dart';

/// P-12 Finding your driver: coral pulse at the pickup, progress bar, trip summary and
/// "Cancel request". The ride controller's timer moves to P-13 (or S-01 when no drivers).
///
/// Live, "Book any" (like Namma Yatra): after [_offerAlternativesAfter] of searching, other vehicles with drivers in
/// range are offered with their fare; adding one lets its drivers take the ride too. After [_offerExtraAfter] the
/// rider can also add a little extra ([AddExtraCard], like Rapido's).
class P12FindingDriverScreen extends ConsumerStatefulWidget {
  const P12FindingDriverScreen({super.key, this.showcase = false});

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  @override
  ConsumerState<P12FindingDriverScreen> createState() => _P12FindingDriverScreenState();
}

const _offerAlternativesAfter = Duration(seconds: 15);
const _refreshAlternativesEvery = Duration(seconds: 10);
const _offerExtraAfter = Duration(seconds: 20);

class _P12FindingDriverScreenState extends ConsumerState<P12FindingDriverScreen> {
  Timer? _alternatives;
  Timer? _extraTimer;

  /// "No driver yet? Add a little extra" is on screen.
  late bool _offerExtra = widget.showcase;

  @override
  void initState() {
    super.initState();
    if (widget.showcase) return;
    if (ref.read(isLiveApiProvider)) {
      _alternatives = Timer(_offerAlternativesAfter, () {
        final flow = ref.read(rideFlowProvider.notifier);
        flow.loadAlternatives();
        _alternatives = Timer.periodic(_refreshAlternativesEvery, (_) => flow.loadAlternatives());
      });
      _extraTimer = Timer(_offerExtraAfter, () {
        if (mounted) setState(() => _offerExtra = true);
      });
    }
    // Opened after the search already finished (e.g. from the Home banner).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _route(ref.read(rideFlowProvider).phase);
    });
  }

  @override
  void dispose() {
    _alternatives?.cancel();
    _extraTimer?.cancel();
    super.dispose();
  }

  Future<void> _addExtra(int amount) async {
    if (widget.showcase) {
      showTtSnack(context, 'Drivers now see your extra');
      return;
    }
    final error = await ref.read(rideFlowProvider.notifier).addExtra(amount);
    if (!mounted) return;
    showTtSnack(context, error ?? 'Added. Drivers now see ${formatInr(ref.read(rideFlowProvider).quote.total)}',
        success: error == null);
  }

  Future<void> _add(VehicleKind v) async {
    final error = await ref.read(rideFlowProvider.notifier).addVehicle(v);
    if (!mounted) return;
    showTtSnack(context, error ?? 'Also looking for ${Seed.vehicle(v).name.toLowerCase()} now', success: error == null);
  }

  void _route(RidePhase phase) {
    if (widget.showcase || !mounted || phase == RidePhase.searching || phase == RidePhase.planning) return;
    // Assigned, no drivers, or further along (a poll can skip steps when the socket was down).
    final route = routeForRidePhase(phase);
    if (route != null) context.go(route);
  }

  Future<void> _cancel() async {
    final error = await ref.read(rideFlowProvider.notifier).cancelSearch();
    if (!mounted) return;
    if (error != null) {
      showTtSnack(context, error);
      return;
    }
    showTtSnack(context, 'Request cancelled');
    context.go(Routes.ride);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(rideFlowProvider.select((s) => s.phase), (_, next) => _route(next));
    final t = context.type;
    final state = ref.watch(rideFlowProvider);
    final q = state.quote;
    final pickup = state.pickup.location;
    // Free vehicles that could take this request (the booked tier and any added with "Book any").
    final vehicles = nearbyMarkers(ref, pickup, kinds: [for (final k in [state.vehicle, ...state.alsoVehicles]) ...k.servedBy]);

    final sheet = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            VehicleArt(q.vehicle.kind, width: 64, height: 48),
            const SizedBox(width: TtSpacing.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Finding a nearby ${_vehicleNames([state.vehicle, ...state.alsoVehicles])}…',
                    style: t.h1,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    state.alsoVehicles.isEmpty
                        ? 'Usually takes under a minute'
                        : 'The first to accept takes it, at their fare',
                    style: t.bodySmall.copyWith(color: TtColors.navy700),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: TtSpacing.l),
        const ClipRRect(
          borderRadius: TtRadii.pillRadius,
          child: LinearProgressIndicator(
            minHeight: 6,
            color: TtColors.coral500,
            backgroundColor: TtColors.coral50,
          ),
        ),
        if (_offerExtra) ...[
          const SizedBox(height: TtSpacing.l),
          AddExtraCard(total: q.total, extra: q.extra, busy: state.busy, onAdd: _addExtra),
        ],
        if (state.alternatives.isNotEmpty) ...[
          const SizedBox(height: TtSpacing.l),
          _BookAnyCard(alternatives: state.alternatives, busy: state.busy, onAdd: _add),
        ],
        const SizedBox(height: TtSpacing.l),
        TtCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: PickupDropConnector(
                  pickupTitle: state.pickup.name.split(' ').first,
                  pickupSubtitle: 'Current location',
                  dropTitle: state.drop.name,
                  dropSubtitle: state.drop.address,
                ),
              ),
              const SizedBox(width: TtSpacing.s),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(formatInr(q.total), style: TtTextStyles.tabular(t.h1)),
                  Text('Cash / UPI', style: t.caption),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: TtSpacing.s),
        TtButton(
          label: 'Cancel request',
          variant: TtButtonVariant.dangerText,
          loading: state.busy,
          onPressed: _cancel,
        ),
      ],
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel();
      },
      child: Scaffold(
        backgroundColor: TtColors.surface,
        body: Stack(
          children: [
            Positioned.fill(
              child: TtMap(
                // Google: centre on the pickup inside the padded area above the sheet (logo stays visible).
                center: TtMap.usesGoogle ? pickup : offsetPoint(pickup, 700, 180),
                mapPadding: sheetMapPadding(MediaQuery.sizeOf(context).height * 0.45),
                zoom: 15,
                pickup: pickup,
                pulseAt: pickup,
                vehicles: vehicles,
                interactive: false,
                showAttribution: false,
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, TtSpacing.m, TtSpacing.l, 0),
                  child: SosButton(size: 56, onPressed: () => context.push(Routes.sos)),
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              // The "Book any" and extra cards can make it tall: it scrolls rather than covering the whole map.
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
                child: FixedBottomSheet(child: Flexible(child: SingleChildScrollView(child: sheet))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "bike", "bike or auto", "bike, auto or cab".
String _vehicleNames(List<VehicleKind> kinds) {
  final names = [for (final k in kinds) Seed.vehicle(k).name.toLowerCase()];
  if (names.length == 1) return names.single;
  return '${names.sublist(0, names.length - 1).join(', ')} or ${names.last}';
}

/// "Taking a while? Add another vehicle": each with drivers nearby, its fare and Add.
class _BookAnyCard extends StatelessWidget {
  const _BookAnyCard({required this.alternatives, required this.busy, required this.onAdd});

  final List<VehicleAlternative> alternatives;
  final bool busy;
  final ValueChanged<VehicleKind> onAdd;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return TtCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Taking a while? Add another vehicle', style: t.bodySemibold),
          const SizedBox(height: TtSpacing.xs),
          Text('Drivers of any vehicle you add can take your ride.', style: t.caption),
          for (final a in alternatives.take(2)) ...[
            const SizedBox(height: TtSpacing.m),
            Row(
              children: [
                Icon(a.vehicle.icon, color: TtColors.coral500, fill: 1, size: 28),
                const SizedBox(width: TtSpacing.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(Seed.vehicle(a.vehicle).name, style: t.bodySemibold),
                      Text(
                        '${a.driversNearby == 1 ? '1 driver' : '${a.driversNearby} drivers'} nearby · '
                        '${a.nearestKm.toStringAsFixed(1)} km',
                        style: t.caption,
                      ),
                    ],
                  ),
                ),
                Text(formatInr(a.quote.total), style: TtTextStyles.tabular(t.bodySemibold)),
                const SizedBox(width: TtSpacing.m),
                TtButton(
                  label: 'Add',
                  expand: false,
                  height: 40,
                  variant: TtButtonVariant.secondary,
                  onPressed: busy ? null : () => onAdd(a.vehicle),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
