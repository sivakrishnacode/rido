import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

import '../../common/launch.dart';
import '../../common/map_insets.dart';
import '../../common/trip_routes.dart';
import '../../router/routes.dart';
import '../../state/ride_flow.dart';
import 'widgets/trip_widgets.dart';

/// P-15 Driver has arrived: success banner, "Waiting time starts in 2:45" countdown, the ride OTP
/// shown large, and the driver with Chat / Call. The ride starts when the driver enters the OTP.
class P15DriverArrivedScreen extends ConsumerStatefulWidget {
  const P15DriverArrivedScreen({super.key, this.showcase = false});

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  @override
  ConsumerState<P15DriverArrivedScreen> createState() => _P15DriverArrivedScreenState();
}

class _P15DriverArrivedScreenState extends ConsumerState<P15DriverArrivedScreen> {
  static const _freeWait = Duration(minutes: 2, seconds: 45);
  Duration _left = _freeWait;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (!widget.showcase) {
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return;
        setState(() => _left -= const Duration(seconds: 1));
        if (_left <= Duration.zero) t.cancel();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

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
    final waitingStarted = _left <= Duration.zero;

    return PopScope(
      canPop: widget.showcase,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: TripSheetScaffold(
        maxSheetFraction: 0.72,
        map: (context, h) {
          final insets = sheetMapInsets(EdgeInsets.fromLTRB(48, 96, 48, h * 0.62), h * 0.62);
          return RidoMap(
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
            RidoBanner(
              type: RidoBannerType.success,
              title: '${driver.firstName} has arrived at your pickup',
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Symbols.timer_rounded, color: RidoColors.coral600, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text.rich(
                    waitingStarted
                        ? TextSpan(text: 'Waiting charges may apply now', style: t.body)
                        : TextSpan(children: [
                            TextSpan(text: 'Waiting time starts in  ', style: t.body),
                            TextSpan(
                              text: formatCountdown(_left),
                              style: RidoTextStyles.tabular(t.bodySemibold),
                            ),
                          ]),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Semantics(
              label: 'Tell ${driver.firstName} this OTP: ${otp.split('').join(' ')}',
              excludeSemantics: true,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                decoration: BoxDecoration(
                  color: RidoColors.coral50,
                  borderRadius: RidoRadii.cardRadius,
                  border: Border.all(color: RidoColors.coral600, width: 2),
                ),
                child: Column(
                  children: [
                    Text('Tell ${driver.firstName} this OTP'.toUpperCase(),
                        style: t.overline.copyWith(color: RidoColors.coral600), textAlign: TextAlign.center),
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
                              decoration: BoxDecoration(color: RidoColors.surface, borderRadius: RidoRadii.cardRadius),
                              child: Text(d, style: t.hero.copyWith(fontSize: 44, height: 1)),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('Your ride starts once he enters it',
                        style: t.body.copyWith(color: RidoColors.navy700), textAlign: TextAlign.center),
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
                    background: RidoColors.coral600,
                    foreground: Colors.white,
                    onPressed: () => callNumber(context, driver.phone, name: driver.firstName),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Pickup · ${ride.pickup.name}',
              style: t.bodySmall.copyWith(color: RidoColors.navy500),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
