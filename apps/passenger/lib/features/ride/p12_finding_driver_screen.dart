import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

import '../../router/routes.dart';
import '../../state/ride_flow.dart';

/// P-12 Finding your driver: coral pulse at the pickup, progress bar, trip summary and
/// "Cancel request". The ride controller's timer moves to P-13 (or S-01 when no drivers).
class P12FindingDriverScreen extends ConsumerStatefulWidget {
  const P12FindingDriverScreen({super.key, this.showcase = false});

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  @override
  ConsumerState<P12FindingDriverScreen> createState() => _P12FindingDriverScreenState();
}

class _P12FindingDriverScreenState extends ConsumerState<P12FindingDriverScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.showcase) return;
    // Opened after the search already finished (e.g. from the Home banner).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _route(ref.read(rideFlowProvider).phase);
    });
  }

  void _route(RidePhase phase) {
    if (widget.showcase || !mounted) return;
    switch (phase) {
      case RidePhase.assigned:
        context.go(Routes.driverAssigned);
      case RidePhase.noDrivers:
        context.go(Routes.noDrivers);
      default:
        break;
    }
  }

  void _cancel() {
    ref.read(rideFlowProvider.notifier).cancelSearch();
    showRidoSnack(context, 'Request cancelled');
    context.go(Routes.ride);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(rideFlowProvider.select((s) => s.phase), (_, next) => _route(next));
    final t = context.type;
    final state = ref.watch(rideFlowProvider);
    final q = state.quote;
    final pickup = state.pickup.location;
    final vehicles = [
      MapVehicle(position: offsetPoint(pickup, 420, 320), type: MapVehicleType.car, heading: 30),
      MapVehicle(position: offsetPoint(pickup, 380, 70), type: MapVehicleType.auto, heading: 110),
      MapVehicle(position: offsetPoint(pickup, 300, 150), type: MapVehicleType.bike, heading: 120),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel();
      },
      child: Scaffold(
        backgroundColor: RidoColors.surface,
        body: Stack(
          children: [
            Positioned.fill(
              child: RidoMap(
                center: offsetPoint(pickup, 700, 180),
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
                  padding: const EdgeInsets.fromLTRB(0, RidoSpacing.m, RidoSpacing.l, 0),
                  child: SosButton(size: 56, onPressed: () => context.push(Routes.sos)),
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: FixedBottomSheet(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: const BoxDecoration(
                            color: RidoColors.coral50,
                            borderRadius: RidoRadii.cardRadius,
                          ),
                          child: Icon(q.vehicle.kind.icon, color: RidoColors.coral500, fill: 1, size: 28),
                        ),
                        const SizedBox(width: RidoSpacing.m),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Finding a nearby ${q.vehicle.name.toLowerCase()}…',
                                style: t.h1,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Usually takes under a minute',
                                style: t.bodySmall.copyWith(color: RidoColors.navy700),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: RidoSpacing.l),
                    const ClipRRect(
                      borderRadius: RidoRadii.pillRadius,
                      child: LinearProgressIndicator(
                        minHeight: 6,
                        color: RidoColors.coral500,
                        backgroundColor: RidoColors.coral50,
                      ),
                    ),
                    const SizedBox(height: RidoSpacing.l),
                    RidoCard(
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
                          const SizedBox(width: RidoSpacing.s),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(formatInr(q.total), style: RidoTextStyles.tabular(t.h1)),
                              Text('Cash / UPI', style: t.caption),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: RidoSpacing.s),
                    RidoButton(label: 'Cancel request', variant: RidoButtonVariant.dangerText, onPressed: _cancel),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
