import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

import '../../router/routes.dart';
import '../../state/ride_flow.dart';
import '../ride/widgets/trip_widgets.dart';
import 'widgets/state_orb.dart';

/// S-02 Driver cancelled: "Karthik had to cancel. We're finding you another driver" with an
/// auto-searching progress bar. Returns to P-13 when a new driver is assigned.
class S02DriverCancelledScreen extends ConsumerStatefulWidget {
  const S02DriverCancelledScreen({super.key, this.showcase = false});

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  @override
  ConsumerState<S02DriverCancelledScreen> createState() => _S02DriverCancelledScreenState();
}

class _S02DriverCancelledScreenState extends ConsumerState<S02DriverCancelledScreen> {
  /// The driver who cancelled (the flow may assign someone new while this screen is open).
  late final _cancelled = ref.read(rideFlowProvider).driver;

  Future<void> _cancel() async {
    if (widget.showcase) {
      Navigator.of(context).maybePop();
      return;
    }
    await ref.read(rideFlowProvider.notifier).cancelRide(reason: 'Driver cancelled');
    if (!mounted) return;
    showRidoSnack(context, 'Ride request cancelled');
    context.go(Routes.ride);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(rideFlowProvider.select((s) => s.phase), (prev, next) {
      if (widget.showcase) return;
      if (next == RidePhase.assigned) context.go(Routes.driverAssigned);
      if (next == RidePhase.noDrivers) context.go(Routes.noDrivers);
    });

    final t = context.type;
    final ride = ref.watch(rideFlowProvider);

    return PopScope(
      canPop: widget.showcase,
      onPopInvokedWithResult: (didPop, _) {
        // Back keeps searching; Home shows the trip banner.
        if (!didPop) context.go(Routes.ride);
      },
      child: TripSheetScaffold(
        map: (context, h) => RidoMap(
          pickup: ride.pickup.location,
          pulseAt: ride.pickup.location,
          pulseColor: RidoColors.success,
          fitPoints: [offsetPoint(ride.pickup.location, 700, 0), offsetPoint(ride.pickup.location, 700, 180)],
          fitPadding: EdgeInsets.fromLTRB(24, 72, 24, h * 0.5),
          attributionAlignment: Alignment.topRight,
        ),
        sheet: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 4),
            Center(
              child: StateOrb(
                size: 120,
                badge: Symbols.sync_rounded,
                badgeColor: RidoColors.coral500,
                label: 'Finding another driver',
                child: Container(
                  width: 78,
                  height: 78,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: RidoColors.surface, width: 3),
                  ),
                  child: RidoAvatar(initials: _cancelled.initials, size: 72, tone: AvatarTone.navy),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('${_cancelled.firstName} had to cancel', style: t.h1, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text("We're finding you another driver",
                style: t.body.copyWith(color: RidoColors.navy700), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: RidoRadii.pillRadius,
              child: LinearProgressIndicator(
                minHeight: 6,
                value: widget.showcase ? 0.02 : null,
                semanticsLabel: 'Searching for another driver',
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(color: RidoColors.inputBg, borderRadius: RidoRadii.cardRadius),
              child: Row(
                children: [
                  const Icon(Symbols.check_circle_rounded, fill: 1, color: RidoColors.success),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('No charge to you · Same fare ${formatInr(ride.quote.total)}',
                        style: t.bodyMedium.copyWith(color: RidoColors.navy700)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                style: TextButton.styleFrom(foregroundColor: RidoColors.error),
                onPressed: _cancel,
                child: const Text('Cancel request'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
