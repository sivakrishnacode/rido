import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' show Marker;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

import '../../router/routes.dart';
import '../../state/ride_flow.dart';
import '../states/s03_cancel_ride_dialog.dart';
import 'p18_share_trip_sheet.dart';
import 'widgets/trip_widgets.dart';

/// P-13 Driver assigned: the driver's bike approaches the pickup on the map; the sheet shows
/// the driver, the ride OTP, Call / Chat / Share trip / Cancel and the trip summary.
class P13DriverAssignedScreen extends ConsumerWidget {
  const P13DriverAssignedScreen({super.key, this.showcase = false});

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  void _back(BuildContext context) {
    if (showcase) {
      Navigator.of(context).maybePop();
    } else {
      // The trip continues; Home shows the "Trip in progress" banner.
      context.go(Routes.ride);
    }
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final reason = await S03CancelRideDialog.show(context);
    if (reason == null || !context.mounted) return;
    await ref.read(rideFlowProvider.notifier).cancelRide(reason: reason);
    if (!context.mounted) return;
    showRidoSnack(context, 'Ride cancelled');
    context.go(Routes.ride);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(rideFlowProvider.select((s) => s.phase), (prev, next) {
      if (showcase) return;
      switch (next) {
        case RidePhase.arrived:
          context.go(Routes.driverArrived);
        case RidePhase.driverCancelled:
          context.go(Routes.driverCancelled);
        case RidePhase.inProgress:
          context.go(Routes.rideInProgress);
        default:
          break;
      }
    });

    final t = context.type;
    final ride = ref.watch(rideFlowProvider);
    final driver = ride.driver;
    final eta = showcase ? 3 : ride.etaMin.clamp(1, 99);
    final approach = ride.approach.isNotEmpty ? ride.approach : fallbackApproach(ride.pickup);
    final vehicle = ref.read(rideFlowProvider.notifier).vehicle;

    return PopScope(
      canPop: showcase,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back(context);
      },
      child: TripSheetScaffold(
        maxSheetFraction: 0.7,
        map: (context, h) => ValueListenableBuilder<VehicleFix?>(
          valueListenable: vehicle,
          builder: (context, live, _) {
            final fix = showcase ? null : live;
            final pos = fix?.position ?? approach.first;
            return RidoMap(
              pickup: ride.pickup.location,
              route: remainingPath(approach, pos, fix?.progress ?? 0),
              vehicles: [
                MapVehicle(
                  position: pos,
                  type: ride.vehicle.mapType,
                  heading: fix?.heading ?? headingBetween(approach.first, approach[1]),
                  large: true,
                ),
              ],
              fitPoints: [...approach, offsetPoint(ride.pickup.location, 250, 0)],
              fitPadding: EdgeInsets.fromLTRB(56, 96, 56, h * 0.66),
              attributionAlignment: Alignment.topCenter,
              extraMarkers: [
                Marker(
                  point: ride.pickup.location,
                  width: 96,
                  height: 44,
                  alignment: const Alignment(0, -1.7),
                  child: Center(child: EtaBubble(text: '$eta min')),
                ),
              ],
            );
          },
        ),
        overlays: [
          TripMapTopBar(onBack: () => _back(context), onSos: () => context.push(Routes.sos)),
        ],
        sheet: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${driver.firstName} is on the way', style: t.h1),
            Text(
              'Arriving in $eta min',
              style: RidoTextStyles.tabular(t.bodyMedium.copyWith(color: RidoColors.success)),
            ),
            const SizedBox(height: 16),
            TripDriverRow(driver: driver),
            const SizedBox(height: 16),
            const RideOtpCard(
              code: Seed.rideOtp,
              caption: 'Share this with your driver to start the ride',
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TripActionButton(
                    icon: Symbols.call_rounded,
                    label: 'Call',
                    caption: 'Masked',
                    background: RidoColors.coral600,
                    foreground: Colors.white,
                    onPressed: () => showRidoSnack(context, 'Calling ${driver.firstName} (number hidden)'),
                  ),
                ),
                Expanded(
                  child: TripActionButton(
                    icon: Symbols.chat_rounded,
                    label: 'Chat',
                    onPressed: () => context.push(Routes.chat),
                  ),
                ),
                Expanded(
                  child: TripActionButton(
                    icon: Symbols.share_location_rounded,
                    label: 'Share trip',
                    background: RidoColors.inputBg,
                    foreground: RidoColors.navy900,
                    onPressed: () => P18ShareTripSheet.show(context),
                  ),
                ),
                Expanded(
                  child: TripActionButton(
                    icon: Symbols.close_rounded,
                    label: 'Cancel',
                    background: RidoColors.errorTint,
                    foreground: RidoColors.error,
                    labelColor: RidoColors.error,
                    onPressed: () => _cancel(context, ref),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            TripRouteSummary(pickup: ride.pickup.name, drop: ride.drop.name, fare: ride.quote.total),
          ],
        ),
      ),
    );
  }
}
