import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

import '../../common/map_insets.dart';
import '../../router/routes.dart';
import '../../state/passenger_session.dart';
import '../../state/ride_flow.dart';
import 'p10b_who_is_riding_sheet.dart';
import 'p11_fare_details_sheet.dart';

/// P-10 Choose vehicle: route map, Bike / Auto / Cab cards ("3 min away · Drop 9:24 PM", Fastest), payment note,
/// Butterfly (women riders: women drivers preferred / only) and "Book Bike · ₹38".
class P10ChooseVehicleScreen extends ConsumerStatefulWidget {
  const P10ChooseVehicleScreen({super.key, this.showcase = false});

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  @override
  ConsumerState<P10ChooseVehicleScreen> createState() => _P10ChooseVehicleScreenState();
}

class _P10ChooseVehicleScreenState extends ConsumerState<P10ChooseVehicleScreen> {
  @override
  void initState() {
    super.initState();
    // Live API: the fares shown and booked are the server's quotes.
    if (!widget.showcase) Future.microtask(() => ref.read(rideFlowProvider.notifier).loadQuotes());
  }

  Future<void> _book() async {
    final state = ref.read(rideFlowProvider);
    final places = ref.read(placesRepositoryProvider);
    final outside =
        ref.read(demoSettingsProvider).outsideServiceArea ||
        !places.isInServiceArea(state.pickup.location) ||
        !places.isInServiceArea(state.drop.location);
    if (outside) {
      context.push(Routes.serviceUnavailable);
      return;
    }
    final error = await ref.read(rideFlowProvider.notifier).book();
    if (!mounted) return;
    if (error != null) {
      showRidoSnack(context, error);
      return;
    }
    context.go(Routes.findingDriver);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final state = ref.watch(rideFlowProvider);
    final flow = ref.read(rideFlowProvider.notifier);
    ref.watch(currentProfileProvider); // Butterfly shows once the profile (gender) has loaded
    final live = ref.watch(isLiveApiProvider);
    // Live API: wait for the server's quotes; never show a locally computed fare.
    final quotesReady = !live || widget.showcase || state.serverQuotes != null;
    final quote = state.quote;
    final route = state.routeOrDefault;
    final womenDriver = flow.womenDriver;
    final fastest = _fastestKind(state.quotes);
    final now = RidoClock.now();
    String subtitleOf(FareQuote q) {
      final eta = q.pickupEtaMin;
      if (eta == null) return womenDriver == WomenDriverPref.only ? 'No women drivers nearby right now' : 'No drivers nearby right now';
      // Drop time from Google's traffic-aware minutes when known (the fare's own minutes are on P-11).
      return '$eta min away · Drop ${formatTime(now.add(Duration(minutes: eta + q.tripMin)))}';
    }

    return Scaffold(
      backgroundColor: RidoColors.surface,
      body: LayoutBuilder(
        builder: (context, c) {
          final sheetH = (c.maxHeight * 0.66).clamp(360.0, 580.0).toDouble();
          final mapH = c.maxHeight - sheetH + RidoSpacing.l;
          return Stack(
            fit: StackFit.expand,
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: mapH,
                child: RidoMap(
                  pickup: state.pickup.location,
                  drop: state.drop.location,
                  route: route,
                  fitPoints: route,
                  fitPadding: const EdgeInsets.fromLTRB(56, 96, 56, 88),
                  // The sheet overlaps the map's bottom edge; keep the Google logo above it.
                  mapPadding: sheetMapPadding(RidoSpacing.l + 8),
                ),
              ),
              Positioned(
                left: 0,
                top: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(RidoSpacing.l, RidoSpacing.m, 0, 0),
                    child: MapCircleButton(
                      icon: Symbols.arrow_back_rounded,
                      tooltip: 'Back',
                      onPressed: () => context.canPop() ? context.pop() : context.go(Routes.ride),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: mapH - 76,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: RidoSpacing.l, vertical: RidoSpacing.s),
                    decoration: const BoxDecoration(
                      color: RidoColors.surface,
                      borderRadius: RidoRadii.pillRadius,
                      boxShadow: RidoShadows.soft,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Symbols.conversion_path_rounded, size: 20, color: RidoColors.coral600),
                        const SizedBox(width: RidoSpacing.s),
                        Text(
                          quotesReady ? state.estimate.label : 'Getting fares…',
                          style: RidoTextStyles.tabular(t.bodySemibold),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: sheetH,
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    color: RidoColors.surface,
                    borderRadius: RidoRadii.sheetTop,
                    boxShadow: RidoShadows.raised,
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      children: [
                        const SheetHandle(),
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.symmetric(horizontal: RidoSpacing.l),
                            children: [
                              Row(
                                children: [
                                  Expanded(child: Text('Choose a ride', style: t.h1)),
                                  TextButton(
                                    onPressed: () => P11FareDetailsSheet.show(context),
                                    style: TextButton.styleFrom(
                                      foregroundColor: RidoColors.coral600,
                                      minimumSize: const Size(48, 48),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Fare details',
                                          style: t.bodySemibold.copyWith(color: RidoColors.coral600),
                                        ),
                                        const Icon(Symbols.chevron_right_rounded, size: 20),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              _RiderRow(
                                rider: state.rider,
                                onTap: () async {
                                  final me = ref.read(currentProfileProvider).firstName;
                                  final choice = await P10bWhoIsRidingSheet.show(context, me: me, current: state.rider);
                                  if (choice != null) flow.setRider(choice.rider);
                                },
                              ),
                              const SizedBox(height: RidoSpacing.s),
                              if (!quotesReady)
                                _QuotesPending(error: state.quotesError, onRetry: flow.loadQuotes)
                              else
                              for (final q in state.quotes) ...[
                                VehicleOptionCard(
                                  icon: q.vehicle.kind.icon,
                                  name: q.vehicle.name,
                                  subtitle: subtitleOf(q),
                                  capacity: q.vehicle.capacityLabel,
                                  fastest: q.vehicle.kind == fastest,
                                  fare: q.total,
                                  badge: q.vehicle.badge,
                                  badgeTone: q.vehicle.badge == 'Comfort' || q.vehicle.badge == 'Fastest'
                                      ? VehicleBadgeTone.navy
                                      : VehicleBadgeTone.coral,
                                  selected: q.vehicle.kind == state.vehicle,
                                  onTap: () => flow.selectVehicle(q.vehicle.kind),
                                ),
                                const SizedBox(height: RidoSpacing.s),
                              ],
                              const Divider(height: RidoSpacing.l),
                              Row(
                                children: [
                                  const Icon(Symbols.payments_rounded, color: RidoColors.navy900),
                                  const SizedBox(width: RidoSpacing.m),
                                  Flexible(
                                    child: Text(
                                      'Cash / UPI to driver',
                                      style: t.bodyMedium,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: RidoSpacing.s),
                                  Flexible(
                                    child: Material(
                                      color: RidoColors.inputBg,
                                      shape: const StadiumBorder(),
                                      clipBehavior: Clip.antiAlias,
                                      child: InkWell(
                                        onTap: () => showRidoSnack(
                                          context,
                                          'Pay your driver by cash or UPI when the ride ends. Rido takes 0% of it.',
                                        ),
                                        child: Container(
                                          constraints: const BoxConstraints(minHeight: 40),
                                          padding: const EdgeInsets.symmetric(horizontal: RidoSpacing.m),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Symbols.info_rounded, size: 18, color: RidoColors.navy700),
                                              const SizedBox(width: 6),
                                              Flexible(
                                                child: Text(
                                                  'Pay your driver directly',
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: t.bodySmall.copyWith(color: RidoColors.navy700),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (flow.canUseButterfly) ...[
                                const SizedBox(height: RidoSpacing.m),
                                ButterflyCard(value: womenDriver, onChanged: flow.setWomenDriver, riderName: state.rider?.firstName),
                              ],
                              const SizedBox(height: RidoSpacing.s),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            RidoSpacing.l,
                            RidoSpacing.s,
                            RidoSpacing.l,
                            RidoSpacing.l,
                          ),
                          child: RidoButton(
                            label: quotesReady ? 'Book ${quote.vehicle.name} · ${formatInr(quote.total)}' : 'Book',
                            loading: state.busy,
                            onPressed: quotesReady && !state.busy ? _book : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The vehicle with the earliest drop (pickup ETA + ride time); null on a tie or when fewer than two are known.
VehicleKind? _fastestKind(List<FareQuote> quotes) {
  final known = [
    for (final q in quotes)
      if (q.pickupEtaMin != null) (kind: q.vehicle.kind, at: q.pickupEtaMin! + q.tripMin),
  ];
  if (known.length < 2) return null;
  known.sort((a, b) => a.at.compareTo(b.at));
  return known[0].at < known[1].at ? known[0].kind : null;
}

/// "Riding: Me" / "Riding: Anjali" chip that opens P-10b "Who's riding?".
class _RiderRow extends StatelessWidget {
  const _RiderRow({required this.rider, required this.onTap});
  final OtherRider? rider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final r = rider;
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: r == null ? RidoColors.inputBg : RidoColors.coral50,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 40),
            padding: const EdgeInsets.symmetric(horizontal: RidoSpacing.m),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(r == null ? Symbols.person_rounded : Symbols.group_rounded,
                    size: 18, color: r == null ? RidoColors.navy700 : RidoColors.coral600, fill: 1),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    r == null ? 'Riding: Me' : 'Riding: ${r.firstName}',
                    style: t.bodySmallMedium.copyWith(color: r == null ? RidoColors.navy700 : RidoColors.coral700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (r?.isWoman ?? false) ...[const SizedBox(width: 4), const ButterflyMark(size: 16)],
                const Icon(Symbols.expand_more_rounded, size: 18, color: RidoColors.navy500),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Butterfly (women riders only): Off / Preferred / Only, with what each one means.
class ButterflyCard extends StatelessWidget {
  const ButterflyCard({super.key, required this.value, required this.onChanged, this.riderName});
  final WomenDriverPref value;
  final ValueChanged<WomenDriverPref> onChanged;

  /// Booked for someone else: "For Anjali: …".
  final String? riderName;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final on = value.isOn;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.all(RidoSpacing.m),
      decoration: BoxDecoration(
        color: on ? RidoColors.butterfly50 : RidoColors.surface,
        borderRadius: RidoRadii.cardRadius,
        border: Border.all(color: on ? RidoColors.butterfly100 : RidoColors.divider, width: on ? 1.5 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: on ? RidoColors.surface : RidoColors.butterfly50,
                  borderRadius: RidoRadii.cardRadius,
                ),
                alignment: Alignment.center,
                child: const ButterflyMark(size: 36),
              ),
              const SizedBox(width: RidoSpacing.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Butterfly', style: t.bodySemibold.copyWith(color: RidoColors.butterfly600, fontSize: 17)),
                    Text(riderName != null ? 'For $riderName: a woman driver' : 'For women riders: ride with a woman driver',
                        style: t.bodySmall.copyWith(color: RidoColors.navy700)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: RidoSpacing.m),
          RidoSegmented<WomenDriverPref>(
            options: WomenDriverPref.values,
            selected: value,
            labelOf: (v) => switch (v) {
              WomenDriverPref.none => 'Any driver',
              WomenDriverPref.preferred => 'Preferred',
              WomenDriverPref.only => 'Women only',
            },
            onChanged: onChanged,
          ),
          if (on) ...[
            const SizedBox(height: RidoSpacing.s),
            Text(
              value == WomenDriverPref.only
                  ? 'Only women drivers get your request. It can take a little longer to find one.'
                  : 'We ask women drivers first. If none is near, the nearest driver can take it.',
              style: t.bodySmall.copyWith(color: RidoColors.navy700),
            ),
          ],
        ],
      ),
    );
  }
}

/// Live API: fares are loading, or failed with [error] (e.g. "Rido isn't in this area yet") and a Retry.
class _QuotesPending extends StatelessWidget {
  const _QuotesPending({required this.error, required this.onRetry});
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final message = error;
    if (message == null) {
      return SkeletonShimmer(
        child: Column(
          children: [
            for (var i = 0; i < 3; i++) ...const [
              SkeletonBox(height: 72),
              SizedBox(height: RidoSpacing.s),
            ],
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: RidoSpacing.l),
      child: Column(
        children: [
          Text(message, style: t.body.copyWith(color: RidoColors.navy700), textAlign: TextAlign.center),
          const SizedBox(height: RidoSpacing.s),
          RidoButton.text(label: 'Try again', onPressed: onRetry),
        ],
      ),
    );
  }
}
