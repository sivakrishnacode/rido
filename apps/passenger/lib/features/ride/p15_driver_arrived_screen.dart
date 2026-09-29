import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';
import 'package:tamiltaxi_ui/tamiltaxi_ui.dart';

import '../../common/launch.dart';
import '../../common/map_insets.dart';
import '../../common/trip_routes.dart';
import '../../router/routes.dart';
import '../../state/ride_flow.dart';
import 'widgets/trip_widgets.dart';

/// P-15 Driver has arrived: success banner, the waiting chip (free minutes left, then the waiting charge adding up,
/// [WaitingTimerChip]), the ride OTP shown large, and the driver with Chat / Call. The ride starts when the driver
/// enters the OTP; the server adds the waiting charge to the fare then.
class P15DriverArrivedScreen extends ConsumerStatefulWidget {
  const P15DriverArrivedScreen({super.key, this.showcase = false});

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  @override
  ConsumerState<P15DriverArrivedScreen> createState() => _P15DriverArrivedScreenState();
}

class _P15DriverArrivedScreenState extends ConsumerState<P15DriverArrivedScreen> {
  /// Design gallery: the driver arrived 15 s ago ("Free waiting · 2:45 left"), frozen.
  late final DateTime _showcaseAt = DateTime.now();

  void _back() {
    if (widget.showcase) {
      Navigator.of(context).maybePop();
    } else {
      context.go(Routes.ride);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(rideFlowProvider.select((s) => s.phase), (prev, next) {
      if (widget.showcase || next == RidePhase.arrived) return;
      final route = routeForRidePhase(next);
      if (route != null) context.go(route);
    });

    final t = context.type;
    final ride = ref.watch(rideFlowProvider);
    final driver = ride.driver;
    final pickup = ride.pickup.location;
    final otp = widget.showcase ? Seed.rideOtp : ride.otp;
    // Live API: the driver's last GPS fix; otherwise parked just beside the pickup.
    final fix = widget.showcase ? null : ref.read(rideFlowProvider.notifier).vehicle.value;
    final vehiclePos = fix?.position ?? offsetPoint(pickup, 70, 60);
    final waiting = widget.showcase
        ? ride.quote.waitingFrom(_showcaseAt.subtract(const Duration(seconds: 15)))
        : ride.waiting ?? ride.quote.waitingFrom(DateTime.now());

    return PopScope(
      canPop: widget.showcase,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: TripSheetScaffold(
        maxSheetFraction: 0.72,
        map: (context, h) {
          final insets = sheetMapInsets(EdgeInsets.fromLTRB(48, 96, 48, h * 0.62), h * 0.62);
          return TtMap(
            center: pickup,
            pickup: pickup,
            zoom: 16,
            vehicles: [
              MapVehicle(position: vehiclePos, type: ride.vehicle.mapType, heading: fix?.heading ?? 250, large: true),
            ],
            fitPoints: [offsetPoint(pickup, 300, 0), offsetPoint(pickup, 300, 180)],
            fitPadding: insets.fit,
            mapPadding: insets.map,
            attributionAlignment: Alignment.topCenter,
          );
        },
        overlays: [TripMapTopBar(onBack: _back, onSos: () => context.push(Routes.sos))],
        sheet: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TtBanner(
              type: TtBannerType.success,
              title: '${driver.firstName} has arrived at your pickup',
            ),
            const SizedBox(height: 14),
            WaitingTimerChip(terms: waiting, clock: widget.showcase ? () => _showcaseAt : null, isTicking: !widget.showcase),
            const SizedBox(height: 14),
            Semantics(
              label: 'Tell ${driver.firstName} this OTP: ${otp.split('').join(' ')}',
              excludeSemantics: true,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                decoration: BoxDecoration(
                  color: TtColors.coral50,
                  borderRadius: TtRadii.cardRadius,
                  border: Border.all(color: TtColors.coral600, width: 2),
                ),
                child: Column(
                  children: [
                    Text('Tell ${driver.firstName} this OTP'.toUpperCase(),
                        style: t.overline.copyWith(color: TtColors.coral600), textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (final d in otp.split(''))
                          Flexible(
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 5),
                              constraints: const BoxConstraints(maxWidth: 60),
                              height: 72,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(color: TtColors.surface, borderRadius: TtRadii.cardRadius),
                              child: Text(d, style: t.hero.copyWith(fontSize: 44, height: 1)),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('Your ride starts once he enters it',
                        style: t.body.copyWith(color: TtColors.navy700), textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            CompactDriverRow(
              driver: driver,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RoundIconAction(
                    icon: Symbols.chat_rounded,
                    tooltip: 'Chat with ${driver.firstName}',
                    onPressed: () => context.push(Routes.chat),
                  ),
                  const SizedBox(width: 10),
                  RoundIconAction(
                    icon: Symbols.call_rounded,
                    tooltip: 'Call ${driver.firstName}',
                    background: TtColors.coral600,
                    foreground: Colors.white,
                    onPressed: () => callNumber(context, driver.phone, name: driver.firstName),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Pickup · ${ride.pickup.name}',
              style: t.bodySmall.copyWith(color: TtColors.navy500),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
