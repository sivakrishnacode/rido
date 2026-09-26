import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

import '../../common/launch.dart';
import '../../common/map_insets.dart';
import '../../common/trip_routes.dart';
import '../../router/routes.dart';
import '../../state/parcel_flow.dart';
import '../ride/widgets/trip_widgets.dart' show remainingPath;
import 'widgets/parcel_widgets.dart';

/// PP-08 Driver assigned / picking up: the goods vehicle drives to the pickup,
/// stepper, driver card, delivery OTP and Call / Chat / Share tracking / Cancel.
class PP08ParcelDriverAssignedScreen extends ConsumerWidget {
  const PP08ParcelDriverAssignedScreen({super.key, this.showcase = false});

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final name = ref.read(parcelFlowProvider).driver.firstName;
    final ok = await showRidoConfirm(
      context,
      title: 'Cancel this delivery?',
      message: '$name is already on the way to the pickup. You can book again any time.',
      confirmLabel: 'Cancel delivery',
      cancelLabel: 'Keep booking',
      destructive: true,
      icon: Symbols.cancel_rounded,
    );
    if (!ok || !context.mounted) return;
    final error = await ref.read(parcelFlowProvider.notifier).cancel();
    if (!context.mounted) return;
    if (error != null) {
      showRidoSnack(context, error);
      return;
    }
    showRidoSnack(context, 'Delivery cancelled');
    context.go(Routes.parcel);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(parcelFlowProvider.select((s) => s.phase), (prev, next) {
      if (showcase || next == ParcelPhase.assigned || next == ParcelPhase.atPickup) return;
      // Picked up / delivered, or back to searching when the driver cancelled.
      final route = routeForParcelPhase(next);
      if (route != null) context.go(route);
    });
    final t = context.type;
    final s = ref.watch(parcelFlowProvider);
    final ctrl = ref.read(parcelFlowProvider.notifier);
    final atPickup = !showcase && s.phase == ParcelPhase.atPickup;
    final driver = s.driver;
    final receiverFirst = s.details.receiverName.split(' ').first;
    final liveApi = !showcase && ref.watch(isLiveApiProvider);
    // Live API: the leg from the driver's first GPS fix (empty until it arrives); mock: a seeded start.
    final approach = liveApi ? s.approach : roadPath(offsetPoint(s.pickup.location, 1100, 210), s.pickup.location, bend: 0.2);
    final start = approach.isNotEmpty ? approach.first : s.pickup.location;
    final eta = s.phase == ParcelPhase.assigned && !showcase ? s.etaMin : 5;
    final height = MediaQuery.sizeOf(context).height;
    final top = MediaQuery.paddingOf(context).top;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(Routes.parcel);
      },
      child: Scaffold(
        backgroundColor: RidoColors.surface,
        body: Stack(
          children: [
            Positioned.fill(
              child: ValueListenableBuilder<VehicleFix?>(
                valueListenable: ctrl.vehicle,
                builder: (context, fix, _) {
                  final live = !showcase && (s.phase == ParcelPhase.assigned || s.phase == ParcelPhase.atPickup);
                  final pos = atPickup ? s.pickup.location : (live && fix != null ? fix.position : start);
                  final heading = live && fix != null
                      ? fix.heading
                      : (approach.length > 1 ? headingBetween(start, approach[1]) : 0.0);
                  final noVehicleYet = liveApi && fix == null && !atPickup;
                  final insets = sheetMapInsets(
                    EdgeInsets.fromLTRB(64, top + 80, 64, height * 0.62 + 32),
                    height * 0.62,
                  );
                  return RidoMap(
                    pickup: s.pickup.location,
                    pulseAt: noVehicleYet ? s.pickup.location : null,
                    route: atPickup || approach.length < 2 ? const [] : remainingPath(approach, pos, fix?.progress ?? 0),
                    fitPoints: approach.length < 2
                        ? [offsetPoint(s.pickup.location, 600, 0), offsetPoint(s.pickup.location, 600, 180)]
                        : [start, s.pickup.location],
                    fitPadding: insets.fit,
                    mapPadding: insets.map,
                    vehicles: noVehicleYet
                        ? const []
                        : [MapVehicle(position: pos, type: s.vehicle.mapType, heading: heading, large: true)],
                    attributionAlignment: Alignment.bottomRight,
                  );
                },
              ),
            ),
            Positioned(
              top: top + 12,
              left: 16,
              child: MapCircleButton(
                icon: Symbols.arrow_back_rounded,
                tooltip: 'Back to Parcel',
                onPressed: () => context.go(Routes.parcel),
              ),
            ),
            Positioned(
              top: top + 12,
              right: 16,
              child: MapCircleButton(
                icon: Symbols.help_rounded,
                tooltip: 'Help',
                onPressed: () => context.push(Routes.help(tripId: s.tripId)),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: ParcelSheetPanel(
                maxHeight: height * 0.62,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        atPickup
                            ? '${driver.firstName} is at the pickup. Hand over the parcel.'
                            : '${driver.firstName} is coming to pick up',
                        style: t.h1,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        atPickup ? 'Check the parcel together before handing it over' : 'Arriving in $eta min',
                        style: t.bodyMedium.copyWith(color: atPickup ? RidoColors.navy700 : RidoColors.success),
                      ),
                      const SizedBox(height: 16),
                      StepperTimeline(steps: parcelSteps, currentIndex: s.stepIndex.clamp(0, 1)),
                      const SizedBox(height: 12),
                      const Divider(),
                      DriverInfoCard(
                        name: driver.name,
                        initials: driver.initials,
                        rating: driver.rating,
                        vehicle: driver.vehicleModel,
                        plate: driver.plate,
                        bordered: false,
                      ),
                      OtpDisplay(
                        label: 'DELIVERY OTP',
                        code: s.details.deliveryOtp,
                        caption: liveApi
                            ? 'Share it with $receiverFirst. The driver needs it at drop-off.'
                            : 'Sent to $receiverFirst by SMS. The driver needs it at drop-off.',
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ParcelRoundAction(
                              icon: Symbols.call_rounded,
                              label: 'Call',
                              bg: RidoColors.coral600,
                              fg: RidoColors.surface,
                              onTap: () => callNumber(context, driver.phone, name: driver.firstName),
                            ),
                          ),
                          Expanded(
                            child: ParcelRoundAction(
                              icon: Symbols.chat_rounded,
                              label: 'Chat',
                              bg: RidoColors.coral50,
                              fg: RidoColors.coral600,
                              onTap: () => context.push(Routes.parcelChat),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: ParcelRoundAction(
                              icon: Symbols.share_location_rounded,
                              label: 'Share tracking',
                              bg: RidoColors.inputBg,
                              fg: RidoColors.navy900,
                              onTap: () => shareParcelWithReceiver(context, s, ctrl.vehicle.value?.position),
                            ),
                          ),
                          Expanded(
                            child: ParcelRoundAction(
                              icon: Symbols.close_rounded,
                              label: 'Cancel',
                              bg: RidoColors.errorTint,
                              fg: RidoColors.error,
                              labelColor: RidoColors.error,
                              onTap: () => _cancel(context, ref),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
