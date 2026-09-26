import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

import '../../common/job_routes.dart';
import '../../common/measure_size.dart';
import '../../router/routes.dart';
import '../../state/driver_account.dart';
import '../../state/driver_location.dart';
import '../../state/driver_session.dart';
import '../../state/live_helpers.dart';
import '../jobs/widgets/job_map.dart';
import '../states/s11_missed_request_banner.dart';
import '../states/s16_gps_weak_banner.dart';
import 'widgets/home_parts.dart';
import 'widgets/navy_header.dart';

/// Designed states of the home screen (D-13, D-14, D-14b, D-25a, D-25b, S-11, S-12, S-16).
enum HomeVariant { live, offline, online, tripBanner, grace, expired, missedRequest, quiet, gpsLost }

/// D-13 Home. One screen for D-13 (offline), D-14 (online), D-14b (trip-in-progress banner),
/// D-25a / D-25b (plan grace / expired), S-11 (missed request), S-12 (online, quiet) and
/// S-16 (GPS lost). [HomeVariant.live] follows the real session; other variants force a look.
/// Live API: opening Home restores the session ([DriverSessionController.attach]); GPS lost, today's
/// figures and the plan come from the phone and the API instead of the demo controls.
class D13HomeScreen extends ConsumerStatefulWidget {
  const D13HomeScreen({super.key, this.variant = HomeVariant.live, this.showcase = false});

  /// Which designed state to show. [HomeVariant.live] follows the real session.
  final HomeVariant variant;

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  @override
  ConsumerState<D13HomeScreen> createState() => _D13HomeScreenState();
}

class _D13HomeScreenState extends ConsumerState<D13HomeScreen> {
  /// Showcase S-11: OK hides the toast locally.
  bool _missedDismissed = false;

  /// Height of the panels over the map (Google logo padding).
  double _panelHeight = 0;

  HomeVariant get _v => widget.variant;
  bool get _live => _v == HomeVariant.live;
  bool get _showcase => widget.showcase || !_live;
  bool get _api => !_showcase && ref.read(isLiveApiProvider);

  @override
  void initState() {
    super.initState();
    if (_api) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(driverSessionProvider.notifier).attach();
      });
    }
  }

  String _greeting() {
    final h = RidoClock.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Future<void> _goOnline() async {
    final demo = ref.read(demoSettingsProvider);
    if (!_api && demo.accountOnHold) {
      context.push(Routes.accountOnHold);
      return;
    }
    if (!ref.read(driverSessionProvider).selfieDoneThisSession) {
      context.push(Routes.selfieCheck);
      return;
    }
    try {
      await ref.read(driverSessionProvider.notifier).goOnline();
    } on LocationProblem catch (e) {
      if (!mounted) return;
      showRidoSnack(
        context,
        e.message,
        actionLabel: e.fix == LocationFix.none ? null : 'Settings',
        onAction: () => ref.read(driverLocatorProvider).openSettings(e.fix),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      // An admin put the account on hold ("Account is on_hold"): S-10 explains it.
      if (e.status == 403 && e.message.contains('on_hold')) {
        context.push(Routes.accountOnHold);
      } else {
        showRidoSnack(context, e.message);
      }
    } on Exception catch (e) {
      if (mounted) showRidoSnack(context, userMessage(e));
    }
  }

  void _goOffline() {
    ref.read(driverSessionProvider.notifier).goOffline();
    showRidoSnack(context, "You're offline. No new requests.");
  }

  Future<void> _resumePlan() async {
    try {
      await ref.read(planProvider.notifier).resume();
      if (mounted) showRidoSnack(context, 'Plan resumed. You can go online.', success: true);
    } on OfflineException {
      if (mounted) showRidoSnack(context, "You're offline. Try again.");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_showcase) {
      ref.listen(driverSessionProvider.select((s) => s.incoming), (prev, next) {
        if (next != null && prev?.id != next.id) context.push(requestRoute(next));
      });
    }

    final session = ref.watch(driverSessionProvider);
    final plan = ref.watch(planProvider).value;
    final demo = ref.watch(demoSettingsProvider);
    final profile = ref.watch(driverProfileProvider).value ?? Seed.karthik;

    // ------------------------------------------------------------ view state
    final online = _live
        ? session.online
        : const {
            HomeVariant.online,
            HomeVariant.tripBanner,
            HomeVariant.missedRequest,
            HomeVariant.quiet,
            HomeVariant.gpsLost,
          }.contains(_v);
    final status = _live
        ? (plan?.status ?? PlanStatus.trial)
        : switch (_v) {
            HomeVariant.grace => PlanStatus.grace,
            HomeVariant.expired => PlanStatus.expired,
            _ => PlanStatus.active,
          };
    final job = _live ? (session.onJob ? session.job : null) : (_v == HomeVariant.tripBanner ? Seed.rideRequest : null);
    final gpsLost = _live ? (_api ? session.gpsLost : demo.gpsLost) && online : _v == HomeVariant.gpsLost;
    final missed = _live
        ? session.missedRequest && online && job == null
        : _v == HomeVariant.missedRequest && !_missedDismissed;
    final quiet = _v == HomeVariant.quiet;
    final delivery = _live ? (_api ? profile.vehicleKind.isGoods : demo.workType == WorkType.deliveries) : false;
    final earnings = _v == HomeVariant.offline ? 0 : (_live ? session.todayEarnings : Seed.todayEarnings);
    final rides = _v == HomeVariant.offline ? 0 : (_live ? session.todayRides : Seed.todayRides);
    final eta = _live ? session.etaMin : 9;
    final price = plan?.monthlyPrice ?? 2000;
    final planEnd = plan?.nextDebit ?? Seed.nextDebit;
    final vehicleType = (job?.vehicle ?? profile.vehicleKind).mapType;

    // ---------------------------------------------------------------- header
    final String subtitle;
    if (job != null) {
      subtitle = job.isDelivery ? 'On a delivery' : 'On a ride';
    } else if (gpsLost) {
      subtitle = 'Online · hidden from riders';
    } else if (quiet) {
      subtitle = 'Online for 18 min';
    } else if (online) {
      subtitle = delivery ? 'Looking for deliveries...' : 'Looking for rides...';
    } else {
      subtitle = _greeting();
    }
    final Widget pill;
    if (gpsLost) {
      pill = const StatusPill(StatusKind.grace, label: 'Online', large: true);
    } else if (online) {
      pill = const StatusPill(StatusKind.online, large: true);
    } else if (status == PlanStatus.grace) {
      pill = const StatusPill(StatusKind.grace, large: true);
    } else if (status == PlanStatus.expired) {
      pill = const StatusPill(StatusKind.expired, large: true);
    } else if (status == PlanStatus.paused) {
      pill = const StatusPill(StatusKind.paused, large: true);
    } else {
      pill = const OfflineHeaderPill();
    }
    final planWarning = !online && (status == PlanStatus.grace || status == PlanStatus.expired || status == PlanStatus.paused);
    final showBadge = !gpsLost && !planWarning && !missed && !quiet;

    // ------------------------------------------------------------- top card
    Widget? topCard;
    if (!online && status == PlanStatus.grace) {
      topCard = GraceBanner(
        daysLeft: plan?.graceDaysLeft ?? 2,
        amount: price,
        onPay: () => context.push(Routes.autopay(purpose: 'pay')),
      );
    } else if (!online && status == PlanStatus.expired) {
      topCard = const DecoratedBox(
        decoration: BoxDecoration(borderRadius: RidoRadii.cardRadius, boxShadow: RidoShadows.soft),
        child: RidoBanner(
          type: RidoBannerType.error,
          title: 'Plan expired',
          message: 'Renew to go online again. Your ratings and documents are saved.',
        ),
      );
    } else if (!online && status == PlanStatus.paused) {
      topCard = const RidoBanner(
        type: RidoBannerType.info,
        icon: Symbols.pause_circle_rounded,
        title: 'Plan paused',
        message: "You can't go online until you resume.",
      );
    } else if (!gpsLost && !missed && !quiet) {
      topCard = TodayCard(
        earnings: earnings,
        rides: rides,
        online: online,
        onEarnings: () => context.go(Routes.earnings),
      );
    }

    // ------------------------------------------------------------------ map
    // The seeded demand zones are for the demo; the live app shows no made-up hotspots.
    final zones = !online || gpsLost || job != null || _api
        ? const <MapZone>[]
        : quiet
            ? demandZones(labelled: const {'Gandhipuram', 'Peelamedu'})
            : demandZones(labelled: const {'Gandhipuram'}, highDemandLabel: true);
    final map = LiveVehicleMap(
      key: ValueKey('home-map-$quiet'),
      vehicleType: vehicleType,
      fixedPosition: _showcase ? Seed.driverHome : null,
      pulse: online && job == null,
      gpsLost: gpsLost,
      zones: zones,
      zoom: quiet ? 13.4 : 14.6,
      mapPadding: EdgeInsets.only(bottom: _panelHeight),
    );

    // ---------------------------------------------------------- bottom panel
    final Widget panel;
    if (job != null) {
      panel = OnlineStatusRow(
        icon: Symbols.pause_circle_rounded,
        title: 'New requests paused',
        subtitle: 'They resume when this ${job.isDelivery ? 'delivery' : 'ride'} ends.',
      );
    } else if (gpsLost) {
      panel = _GpsTips(onGoOffline: _goOfflineOrShowcase);
    } else if (quiet) {
      panel = _QuietPanel(onGoOffline: _goOfflineOrShowcase);
    } else if (online) {
      panel = Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        OnlineStatusRow(
          title: "You're online",
          subtitle: missed
              ? 'Keep the app open and volume up.'
              : (_api ? 'Keep the app open. Requests pop up here.' : 'Move towards Gandhipuram for faster requests.'),
        ),
        const SizedBox(height: RidoSpacing.l),
        RidoButton.secondary(label: 'Go offline', onPressed: _goOfflineOrShowcase),
      ]);
    } else {
      panel = _OfflinePanel(
        status: status,
        delivery: delivery,
        planLabel: '${(plan?.vehicle ?? profile.vehicleKind).label} plan',
        planEnd: planEnd,
        graceDays: plan?.graceDaysLeft ?? 2,
        price: price,
        onGoOnline: _goOnline,
        goingOnline: session.goingOnline,
        onRenew: () => context.push(Routes.autopay(purpose: 'pay')),
        onResume: _resumePlan,
        onPlan: () => context.go(Routes.plan),
      );
    }

    return Scaffold(
      backgroundColor: RidoColors.background,
      body: Column(
        children: [
          HomeHeader(
            initials: profile.initials,
            firstName: profile.firstName,
            subtitle: subtitle,
            pill: pill,
            onlineRing: online && !gpsLost,
            showBadge: showBadge,
          ),
          if (job != null)
            TripInProgressBanner(
              title: '${job.isDelivery ? 'Delivery' : 'Ride'} in progress${eta > 0 ? ' · $eta min' : ''}',
              subtitle: '${job.customerName} → ${job.drop.name}',
              onOpen: () {
                final route = routeForJob(_live ? session.phase : JobPhase.toDrop, delivery: job.isDelivery);
                if (route != null) context.push(route);
              },
            ),
          if (gpsLost)
            S16GpsWeakBanner(
              onFix: _api ? () => ref.read(driverLocatorProvider).openSettings(LocationFix.locationSettings) : null,
            ),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(child: map),
                if (topCard != null)
                  Positioned(left: RidoSpacing.gutter, right: RidoSpacing.gutter, top: RidoSpacing.l, child: topCard),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: MeasureSize(
                    onChange: (size) {
                      if (mounted && size.height != _panelHeight) setState(() => _panelHeight = size.height);
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (missed)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(RidoSpacing.gutter, 0, RidoSpacing.gutter, RidoSpacing.l),
                            child: S11MissedRequestBanner(
                              showcase: _showcase,
                              delivery: delivery,
                              onDismiss: _live ? null : () => setState(() => _missedDismissed = true),
                            ),
                          ),
                        BottomPanel(child: panel),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _goOfflineOrShowcase() {
    if (_live) {
      _goOffline();
    } else {
      showRidoSnack(context, "You're offline. No new requests.");
    }
  }
}

class _OfflinePanel extends StatelessWidget {
  const _OfflinePanel({
    required this.status,
    required this.delivery,
    required this.planLabel,
    required this.planEnd,
    required this.graceDays,
    required this.price,
    required this.onGoOnline,
    this.goingOnline = false,
    required this.onRenew,
    required this.onResume,
    required this.onPlan,
  });

  final PlanStatus status;
  final bool delivery;
  final String planLabel;
  final DateTime planEnd;
  final int graceDays;
  final int price;
  final VoidCallback onGoOnline;
  final bool goingOnline;
  final VoidCallback onRenew;
  final VoidCallback onResume;
  final VoidCallback onPlan;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final children = <Widget>[];
    switch (status) {
      case PlanStatus.expired:
        children.addAll([
          const GoOnlineButton(onPressed: null),
          const SizedBox(height: RidoSpacing.xl),
          RidoButton(label: 'Renew ${formatInr(price)}', onPressed: onRenew),
        ]);
      case PlanStatus.paused:
        children.addAll([
          const GoOnlineButton(onPressed: null),
          const SizedBox(height: RidoSpacing.xl),
          RidoButton(label: 'Resume plan', icon: Symbols.play_circle_rounded, onPressed: onResume),
        ]);
      case PlanStatus.grace:
        children.addAll([
          GoOnlineButton(onPressed: onGoOnline, loading: goingOnline),
          const SizedBox(height: RidoSpacing.xl),
          PlanStrip(
            warning: true,
            text: 'Grace ends ${formatDate(planEnd.add(Duration(days: graceDays)))}, 11:59 PM',
            onTap: onPlan,
          ),
        ]);
      case PlanStatus.trial || PlanStatus.active || PlanStatus.cancelled:
        children.addAll([
          Text(
            "You're offline. Go online to get ${delivery ? 'delivery' : 'ride'} requests.",
            textAlign: TextAlign.center,
            style: t.body.copyWith(color: RidoColors.navy700),
          ),
          const SizedBox(height: RidoSpacing.l),
          GoOnlineButton(onPressed: onGoOnline, loading: goingOnline),
          const SizedBox(height: RidoSpacing.l),
          PlanStrip(
            text: status == PlanStatus.cancelled
                ? 'Plan cancelled · active till ${formatDate(planEnd)}'
                : '$planLabel active till ${formatDate(planEnd)}',
            onTap: onPlan,
          ),
        ]);
    }
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }
}

class _QuietPanel extends StatelessWidget {
  const _QuietPanel({required this.onGoOffline});
  final VoidCallback onGoOffline;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Waiting for rides…', style: t.display),
      const SizedBox(height: RidoSpacing.l),
      Container(
        padding: const EdgeInsets.all(RidoSpacing.l),
        decoration: const BoxDecoration(color: RidoColors.coral50, borderRadius: RidoRadii.cardRadius),
        child: Row(children: [
          const Icon(Symbols.emoji_objects_rounded, color: RidoColors.coral600, fill: 1, size: 28),
          const SizedBox(width: RidoSpacing.m),
          Expanded(
            child: Text.rich(TextSpan(children: [
              const TextSpan(text: 'Busy areas right now:\n'),
              TextSpan(text: 'Gandhipuram, Peelamedu', style: t.bodySemibold),
            ])),
          ),
        ]),
      ),
      const SizedBox(height: RidoSpacing.l),
      RidoButton.secondary(label: 'Go offline', onPressed: onGoOffline),
    ]);
  }
}

class _GpsTips extends StatelessWidget {
  const _GpsTips({required this.onGoOffline});
  final VoidCallback onGoOffline;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    Widget tip(IconData icon, String text) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            Icon(icon, color: RidoColors.navy700, size: 24),
            const SizedBox(width: RidoSpacing.m),
            Expanded(child: Text(text, style: t.body)),
          ]),
        );
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('TRY THIS', style: t.overline),
      const SizedBox(height: RidoSpacing.s),
      tip(Symbols.location_on_rounded, 'Turn on Location · High accuracy'),
      tip(Symbols.battery_saver_rounded, 'Turn off battery saver for Rido Driver'),
      tip(Symbols.light_mode_rounded, 'Move out from under a flyover or building'),
      Align(
        alignment: Alignment.centerLeft,
        child: RidoButton.text(label: 'Go offline', onPressed: onGoOffline),
      ),
    ]);
  }
}
