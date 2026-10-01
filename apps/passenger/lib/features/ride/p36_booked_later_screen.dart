import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';
import 'package:tamiltaxi_ui/tamiltaxi_ui.dart';

import '../../router/routes.dart';
import 'widgets/upcoming_trip_card.dart';

/// P-36 Booked for later: the rental / outstation trip is booked for its time. What happens next (we find the driver
/// 30 min before; free to cancel until then), the booking, then Done (Home) or See my trips (Activity).
class P36BookedLaterScreen extends ConsumerWidget {
  const P36BookedLaterScreen({super.key, this.trip, this.showcase = false});

  /// The booked trip (route `extra`); a sample in the Design gallery.
  final Trip? trip;
  final bool showcase;

  static Trip get _sample {
    final q = RideModeRates.quotesFor(Seed.gandhipuram, null, const ModeRequest(mode: RideMode.rental, packageId: '4h'))[1];
    return Trip(
      id: 'RD-SAMPLE',
      kind: TripKind.ride,
      vehicle: VehicleKind.sedan,
      pickup: Seed.gandhipuram,
      drop: Seed.gandhipuram,
      fare: q.total,
      quote: q,
      status: TripStatus.scheduled,
      startedAt: DateTime(2026, 10, 5, 9),
      rideMode: RideMode.rental,
      modeTerms: q.modeTerms,
      scheduledAt: DateTime(2026, 10, 6, 6),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.type;
    final booked = trip ?? _sample;
    final at = booked.scheduledAt;
    return Scaffold(
      backgroundColor: TtColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(TtSpacing.l, TtSpacing.xxl, TtSpacing.l, TtSpacing.l),
                children: [
                  const Center(child: _BookedOrb()),
                  const SizedBox(height: TtSpacing.l),
                  Text("You're booked", style: t.display, textAlign: TextAlign.center),
                  const SizedBox(height: TtSpacing.xs),
                  Text(
                    at == null ? 'for later' : 'for ${formatWhen(at)}',
                    style: t.h2.copyWith(color: TtColors.coral600),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: TtSpacing.xl),
                  UpcomingTripCard(trip: booked, showWhen: false),
                  const SizedBox(height: TtSpacing.l),
                  const _NextSteps(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(TtSpacing.l, TtSpacing.s, TtSpacing.l, TtSpacing.l),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TtButton(label: 'Done', onPressed: showcase ? () {} : () => context.go(Routes.ride)),
                  const SizedBox(height: TtSpacing.s),
                  TtButton.secondary(label: 'See my trips', onPressed: showcase ? () {} : () => context.go(Routes.activity)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// What happens before the trip.
class _NextSteps extends StatelessWidget {
  const _NextSteps();

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    const steps = [
      (Symbols.travel_explore_rounded, 'We start finding your driver 30 minutes before the pickup time.'),
      (Symbols.notifications_active_rounded, "You get a notification with the driver's name and number plate."),
      (Symbols.event_busy_rounded, 'Plans changed? Cancel for free from Activity until the search starts.'),
    ];
    return Container(
      padding: const EdgeInsets.all(TtSpacing.l),
      decoration: const BoxDecoration(color: TtColors.surface, borderRadius: TtRadii.cardRadius),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('What happens next', style: t.bodySemibold),
          const SizedBox(height: TtSpacing.m),
          for (final (icon, text) in steps)
            Padding(
              padding: const EdgeInsets.only(bottom: TtSpacing.m),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(color: TtColors.coral50, shape: BoxShape.circle),
                    child: Icon(icon, size: 18, color: TtColors.coral600),
                  ),
                  const SizedBox(width: TtSpacing.m),
                  Expanded(child: Text(text, style: t.bodySmall.copyWith(color: TtColors.navy700))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// A calendar with a tick on the coral orbs (the illustration style).
class _BookedOrb extends StatelessWidget {
  const _BookedOrb();

  @override
  Widget build(BuildContext context) => Semantics(
        image: true,
        label: 'Booked',
        child: Container(
          width: 148,
          height: 148,
          decoration: const BoxDecoration(color: TtColors.coral50, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Container(
            width: 104,
            height: 104,
            decoration: const BoxDecoration(color: TtColors.coral100, shape: BoxShape.circle),
            child: const Icon(Symbols.event_available_rounded, size: 56, color: TtColors.coral600, fill: 1),
          ),
        ),
      );
}
