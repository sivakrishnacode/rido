import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

import '../../router/routes.dart';
import '../../state/parcel_flow.dart';
import 'widgets/parcel_widgets.dart';

/// PP-09 Parcel in transit: live tracking to the drop, ETA, stepper at "Picked up",
/// share tracking. Goods only, so no SOS: a Help icon sits in the top bar instead.
class PP09ParcelInTransitScreen extends ConsumerWidget {
  const PP09ParcelInTransitScreen({super.key, this.showcase = false});

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(parcelFlowProvider.select((s) => s.phase), (prev, next) {
      if (showcase) return;
      if (next == ParcelPhase.delivered) context.go(Routes.parcelDelivered);
    });
    final t = context.type;
    final s = ref.watch(parcelFlowProvider);
    final ctrl = ref.read(parcelFlowProvider.notifier);
    final driver = s.driver;
    final receiverFirst = s.details.receiverName.split(' ').first;
    final route = s.routeOrDefault;
    final now = RidoClock.now();
    final eta = s.phase == ParcelPhase.inTransit && !showcase ? s.etaMin : 15;
    final arriving = now.add(Duration(minutes: eta));
    final pickedUpAt = now.subtract(Duration(minutes: (s.estimate.durationMin - eta).clamp(1, 120)));
    final live = !showcase && s.phase == ParcelPhase.inTransit;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(Routes.parcel);
      },
      child: Scaffold(
        backgroundColor: RidoColors.surface,
        appBar: AppBar(
          backgroundColor: RidoColors.surface,
          automaticallyImplyLeading: false,
          toolbarHeight: 64,
          titleSpacing: 0,
          leading: IconButton(
            tooltip: 'Back to Parcel',
            icon: const Icon(Symbols.arrow_back_rounded, color: RidoColors.navy900),
            onPressed: () => context.go(Routes.parcel),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Parcel to', style: t.caption.copyWith(color: RidoColors.navy500)),
              Text('${s.details.receiverName} · ${s.drop.name}',
                  style: t.h2, maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Help',
              icon: const Icon(Symbols.help_rounded, color: RidoColors.navy900),
              onPressed: () => context.push(Routes.help(tripId: s.tripId)),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ValueListenableBuilder<VehicleFix?>(
                      valueListenable: ctrl.vehicle,
                      builder: (context, fix, _) {
                        final progress = live && fix != null ? fix.progress : 0.3;
                        final pos = live && fix != null ? fix.position : pointAlong(route, progress);
                        final i = (progress * (route.length - 1)).floor().clamp(0, route.length - 2);
                        final heading = live && fix != null ? fix.heading : headingBetween(route[i], route[i + 1]);
                        return RidoMap(
                          drop: s.drop.location,
                          route: [pos, ...route.skip(i + 1)],
                          fitPoints: route,
                          fitPadding: const EdgeInsets.fromLTRB(56, 96, 56, 56),
                          vehicles: [MapVehicle(position: pos, type: s.vehicle.mapType, heading: heading, large: true)],
                          attributionAlignment: Alignment.bottomRight,
                        );
                      },
                    ),
                  ),
                  Positioned(
                    top: 16,
                    left: 16,
                    child: Semantics(
                      liveRegion: true,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: const BoxDecoration(color: RidoColors.navy900, borderRadius: RidoRadii.pillRadius),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Symbols.schedule_rounded, color: RidoColors.surface, size: 20),
                            const SizedBox(width: 8),
                            Text('Arriving ${formatTime(arriving)}',
                                style: RidoTextStyles.tabular(t.bodySemibold.copyWith(color: RidoColors.surface))),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ParcelSheetPanel(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    StepperTimeline(steps: parcelSteps, currentIndex: s.stepIndex < 2 ? 2 : s.stepIndex),
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        RidoAvatar(initials: driver.initials, size: 44, tone: AvatarTone.navy),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${driver.name} · ${driver.plate}',
                                  style: t.bodySemibold, maxLines: 1, overflow: TextOverflow.ellipsis),
                              Text(
                                'Picked up ${formatTime(pickedUpAt)} · ${s.details.category.label}',
                                style: t.bodySmall.copyWith(color: RidoColors.navy500),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Material(
                          color: RidoColors.coral600,
                          shape: const CircleBorder(),
                          child: IconButton(
                            tooltip: 'Call ${driver.firstName}',
                            onPressed: () => showRidoSnack(context, 'Calling ${driver.firstName} (number hidden)'),
                            icon: const Icon(Symbols.call_rounded, fill: 1, color: RidoColors.surface),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    RidoButton.secondary(
                      label: 'Share tracking with receiver',
                      icon: Symbols.share_location_rounded,
                      onPressed: () => showRidoSnack(context, 'Tracking link shared with $receiverFirst', success: true),
                    ),
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
