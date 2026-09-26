import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

import '../../common/launch.dart';
import '../../router/routes.dart';
import '../../state/driver_session.dart';
import '../../state/live_helpers.dart';
import '../home/widgets/navy_header.dart';
import 'widgets/job_common.dart';
import 'widgets/job_map.dart';

/// D-18 Ride in progress: turn-by-turn strip with ETA, route to the drop with the moving
/// vehicle, SOS (→ D-18b) and "Swipe to end ride" (→ D-19). Back asks before leaving;
/// the D-14b banner on Home reopens the trip. Live API: the strip shows the drop (no turn-by-turn;
/// the ETA follows the GPS along the route) and ending the ride completes the trip on the server.
class D18RideInProgressScreen extends ConsumerStatefulWidget {
  const D18RideInProgressScreen({super.key, this.showcase = false});

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  @override
  ConsumerState<D18RideInProgressScreen> createState() => _D18RideInProgressScreenState();
}

class _D18RideInProgressScreenState extends ConsumerState<D18RideInProgressScreen> {
  late final RideRequest _job = ref.read(driverSessionProvider).job ?? Seed.rideRequest;
  late final List<LatLng> _fallbackRoute =
      roadPath(_job.pickup.location, _job.drop.location, mode: travelModeFor(_job.vehicle));
  late final bool _api = !widget.showcase && ref.read(isLiveApiProvider);
  bool _busy = false;

  Future<void> _endRide(bool live) async {
    if (_busy) return;
    if (live) {
      setState(() => _busy = true);
      try {
        await ref.read(driverSessionProvider.notifier).endRide();
      } on Exception catch (e) {
        if (!mounted) return;
        setState(() => _busy = false);
        showRidoSnack(context, userMessage(e));
        return;
      }
      if (!mounted) return;
    }
    if (widget.showcase) {
      context.push(Routes.collect);
    } else {
      context.pushReplacement(Routes.collect);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final session = ref.watch(driverSessionProvider);
    final live = !widget.showcase && session.job != null;
    final route = live && session.route.isNotEmpty ? session.route : _fallbackRoute;
    final eta = live ? session.etaMin : 9;
    final arrival = RidoClock.now().add(Duration(minutes: eta));

    return PopScope(
      canPop: !live,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) confirmLeaveJob(context);
      },
      child: Scaffold(
        backgroundColor: RidoColors.background,
        body: Column(
          children: [
            NavyHeader(
              padding: const EdgeInsets.fromLTRB(RidoSpacing.gutter, RidoSpacing.m, RidoSpacing.gutter, RidoSpacing.m),
              child: Row(children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(color: RidoColors.success, borderRadius: RidoRadii.cardRadius),
                  child: Icon(_api ? Symbols.navigation_rounded : Symbols.turn_left_rounded, color: Colors.white, size: 30),
                ),
                const SizedBox(width: RidoSpacing.m),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(eta <= 1 ? 'Arriving at drop' : (_api ? 'Going to drop' : 'In 300 m, turn left'),
                        style: t.h2.copyWith(color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(eta <= 1 || _api ? _job.drop.name : 'onto DB Road',
                        style: t.bodySmall.copyWith(color: Colors.white70), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ]),
                ),
                const SizedBox(width: RidoSpacing.s),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('$eta min', style: RidoTextStyles.tabular(t.h2.copyWith(color: Colors.white))),
                  Text(formatTime(arrival), style: RidoTextStyles.tabular(t.bodySmall.copyWith(color: Colors.white70))),
                ]),
              ]),
            ),
            Expanded(
              child: Stack(children: [
                Positioned.fill(
                  child: LiveVehicleMap(
                    vehicleType: _job.vehicle.mapType,
                    fixedPosition: live ? null : pointAlong(route, 0.45),
                    drop: _job.drop.location,
                    route: route,
                    fitPoints: route,
                    fitPadding: const EdgeInsets.fromLTRB(56, 72, 56, 96),
                    centerOnVehicle: false,
                  ),
                ),
                if (_api)
                  Positioned(
                    right: RidoSpacing.gutter,
                    top: RidoSpacing.l,
                    child: NavigatePill(onPressed: () => openNavigation(context, _job.drop.location)),
                  ),
                Positioned(
                  right: RidoSpacing.gutter,
                  bottom: RidoSpacing.xl,
                  child: SosButton(onPressed: () => context.push(Routes.sos)),
                ),
              ]),
            ),
            BottomPanel(
              handle: true,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Padding(padding: EdgeInsets.only(top: 2), child: DropPin(size: 28)),
                  const SizedBox(width: RidoSpacing.m),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_job.drop.name, style: t.h2, maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(_job.drop.address, style: t.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ]),
                  ),
                  const SizedBox(width: RidoSpacing.s),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(formatInr(_job.fare), style: RidoTextStyles.tabular(t.h1)),
                    Text(_job.customerName, style: t.bodySmall.copyWith(color: RidoColors.navy500)),
                  ]),
                ]),
                const SizedBox(height: RidoSpacing.l),
                SwipeToConfirm(label: 'Swipe to end ride', enabled: !_busy, onConfirmed: () => _endRide(live)),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
