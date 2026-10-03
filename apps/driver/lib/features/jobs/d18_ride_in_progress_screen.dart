import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';
import 'package:tamiltaxi_ui/tamiltaxi_ui.dart';

import '../../common/showcase.dart';
import '../../common/launch.dart';
import '../../router/routes.dart';
import '../../state/driver_session.dart';
import '../../state/live_helpers.dart';
import '../home/widgets/navy_header.dart';
import 'widgets/job_common.dart';
import 'widgets/too_far_sheet.dart';
import 'widgets/job_map.dart';

/// D-18 Ride in progress: turn-by-turn strip with ETA, route to the drop with the moving
/// vehicle, SOS (→ D-18b) and "Swipe to end ride" (→ D-19). Back asks before leaving;
/// the D-14b banner on Home reopens the trip. Live API: the strip shows the drop (no turn-by-turn;
/// the ETA follows the GPS along the route) and ending the ride completes the trip on the server.
/// A rental has no drop: the strip shows the time used of the package, the map just the cab, and it ends wherever
/// the rider gets off (so does a round trip).
class D18RideInProgressScreen extends ConsumerStatefulWidget {
  const D18RideInProgressScreen({super.key, this.showcase = false, this.sample});

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  /// Design gallery: the trip shown (default: the bike ride).
  final RideRequest? sample;

  @override
  ConsumerState<D18RideInProgressScreen> createState() => _D18RideInProgressScreenState();
}

class _D18RideInProgressScreenState extends ConsumerState<D18RideInProgressScreen> {
  late final RideRequest _job = (widget.showcase ? null : ref.read(driverSessionProvider).job) ?? widget.sample ?? Seed.rideRequest;
  late final List<LatLng> _fallbackRoute =
      _job.isRental ? const [] : roadPath(_job.pickup.location, _job.drop.location, mode: travelModeFor(_job.vehicle));
  late final bool _api = !widget.showcase && ref.read(isLiveApiProvider);
  bool _busy = false;

  /// A rental's clock: the time used of the package, refreshed every half minute.
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    if (_job.isRental && !widget.showcase) {
      _clock = Timer.periodic(const Duration(seconds: 30), (_) => mounted ? setState(() {}) : null);
    }
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  /// Minutes since the rental started (the gallery: 1 h 12 min in).
  int get _usedMin {
    if (widget.showcase) return 72;
    final at = _job.rideStartedAt;
    return at == null ? 0 : DateTime.now().difference(at).inMinutes;
  }

  Future<void> _endRide(bool live) async {
    if (_busy) return;
    if (live) {
      setState(() => _busy = true);
      final session = ref.read(driverSessionProvider.notifier);
      bool done;
      try {
        // Far from the drop the API asks for a reason (TooFarSheet), then the ride ends.
        done = await runWithFarCheck(context, (r) => session.endRide(farReason: r), target: _job.drop.location);
      } on Exception catch (e) {
        if (!mounted) return;
        setState(() => _busy = false);
        showTtSnack(context, userMessage(e));
        return;
      }
      if (!mounted) return;
      if (!done) {
        setState(() => _busy = false);
        return;
      }
    }
    if (widget.showcase) return showTtSnack(context, kPreviewNote);
    context.pushReplacement(Routes.collect);
  }

  /// Live API: warns early when the GPS is already outside the drop radius (the API decides).
  String _endLabel() {
    if (_job.endsAnywhere) return 'Swipe to end trip';
    final m = _api ? ref.read(driverSessionProvider.notifier).metresTo(_job.drop.location) : null;
    return m != null && m > kDropRadiusM ? 'End ride · ${formatMetres(m)} from drop' : 'Swipe to end ride';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final session = ref.watch(driverSessionProvider);
    final live = !widget.showcase && session.job != null;
    final route = live && session.route.isNotEmpty ? session.route : _fallbackRoute;
    final eta = live ? session.etaMin : (_job.isOutstation ? _job.tripMin : 9);
    final arrival = TtClock.now().add(Duration(minutes: eta));
    final rental = _job.modeTerms is RentalTerms ? _job.modeTerms! as RentalTerms : null;

    return PopScope(
      canPop: !live,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) confirmLeaveJob(context);
      },
      child: Scaffold(
        backgroundColor: TtColors.background,
        body: Column(
          children: [
            NavyHeader(
              padding: const EdgeInsets.fromLTRB(
                TtSpacing.gutter,
                TtSpacing.m,
                TtSpacing.gutter,
                TtSpacing.m,
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: TtColors.success,
                      borderRadius: TtRadii.cardRadius,
                    ),
                    child: Icon(
                      _job.isRental
                          ? Symbols.timer_rounded
                          : (_api || _job.isOutstation
                                ? Symbols.navigation_rounded
                                : Symbols.turn_left_rounded),
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: TtSpacing.m),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _job.isRental
                              ? 'Rental in progress'
                              : eta <= 1
                              ? 'Arriving at drop'
                              : (_api || _job.isOutstation
                                    ? 'Going to drop'
                                    : 'In 300 m, turn left'),
                          style: t.h2.copyWith(color: Colors.white),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          _job.isRental
                              ? 'Ends where ${_job.customerName.split(' ').first} gets off'
                              : (eta <= 1 || _api || _job.isOutstation
                                    ? _job.drop.name
                                    : 'onto DB Road'),
                          style: t.bodySmall.copyWith(color: Colors.white70),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: TtSpacing.s),
                  if (rental != null)
                    // Time used of the package; past it, the extra minutes are charged (coral).
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          formatMinutes(_usedMin),
                          style: TtTextStyles.tabular(
                            t.h2.copyWith(
                              color: _usedMin > rental.hours * 60
                                  ? TtColors.coral100
                                  : Colors.white,
                            ),
                          ),
                        ),
                        Text(
                          'of ${rental.package.hoursLabel}',
                          style: t.bodySmall.copyWith(color: Colors.white70),
                        ),
                      ],
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          formatMinutes(eta),
                          style: TtTextStyles.tabular(
                            t.h2.copyWith(color: Colors.white),
                          ),
                        ),
                        Text(
                          formatTime(arrival),
                          style: TtTextStyles.tabular(
                            t.bodySmall.copyWith(color: Colors.white70),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: _job.isRental
                        // No drop: just the cab, followed.
                        ? LiveVehicleMap(
                            vehicleType: _job.vehicle.mapType,
                            fixedPosition: live
                                ? null
                                : Seed.raceCourse.location,
                            zoom: 15,
                          )
                        : LiveVehicleMap(
                            vehicleType: _job.vehicle.mapType,
                            fixedPosition: live
                                ? null
                                : pointAlong(route, 0.45),
                            drop: _job.drop.location,
                            route: route,
                            fitPoints: route,
                            fitPadding: const EdgeInsets.fromLTRB(
                              56,
                              72,
                              56,
                              96,
                            ),
                            centerOnVehicle: false,
                          ),
                  ),
                  if (_api && !_job.isRental)
                    Positioned(
                      right: TtSpacing.gutter,
                      top: TtSpacing.l,
                      child: NavigatePill(
                        onPressed: unlessShowcase(
                          context,
                          widget.showcase,
                          () => openNavigation(context, _job.drop.location),
                        )!,
                      ),
                    ),
                  Positioned(
                    left: TtSpacing.gutter,
                    bottom: TtSpacing.xl,
                    child: Material(
                      shape: const CircleBorder(),
                      elevation: 4,
                      shadowColor: TtColors.shadow,
                      child: RoundIconButton(
                        icon: Symbols.chat_rounded,
                        tooltip: 'Chat with ${_job.customerName}',
                        onPressed: unlessShowcase(
                          context,
                          widget.showcase,
                          () => context.push(Routes.chat),
                        )!,
                      ),
                    ),
                  ),
                  Positioned(
                    right: TtSpacing.gutter,
                    bottom: TtSpacing.xl,
                    child: SosButton(
                      onPressed: unlessShowcase(
                        context,
                        widget.showcase,
                        () => context.push(Routes.sos),
                      )!,
                    ),
                  ),
                ],
              ),
            ),
            BottomPanel(
              handle: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (rental != null)
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(
                            Symbols.timer_rounded,
                            size: 28,
                            color: TtColors.coral600,
                            fill: 1,
                          ),
                        )
                      else
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: DropPin(size: 28),
                        ),
                      const SizedBox(width: TtSpacing.m),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              rental != null
                                  ? '${rental.package.label} package'
                                  : _job.drop.name,
                              style: t.h2,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              rental != null
                                  ? 'Then ${_rate(rental.extraKmRate)} a km, ${_rate(rental.extraMinRate)} a min'
                                  : [
                                      _job.drop.address,
                                      ?_job.modeLabel,
                                    ].where((s) => s.isNotEmpty).join(' · '),
                              style: t.bodySmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: TtSpacing.s),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            formatInr(_job.fare),
                            style: TtTextStyles.tabular(t.h1),
                          ),
                          // A rental's extras are added when it ends.
                          if (rental != null)
                            Text(
                              'so far',
                              style: t.caption.copyWith(
                                color: TtColors.navy500,
                              ),
                            ),
                          Text(
                            _job.customerName,
                            style: t.bodySmall.copyWith(
                              color: TtColors.navy500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: TtSpacing.l),
                  SwipeToConfirm(
                    label: _endLabel(),
                    enabled: !_busy,
                    onConfirmed: () => _endRide(live),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _rate(double r) => r == r.roundToDouble() ? formatInr(r) : '₹${r.toStringAsFixed(1)}';
}
