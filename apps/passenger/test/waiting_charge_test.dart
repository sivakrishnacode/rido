import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_passenger/features/activity/p22_trip_details_screen.dart';
import 'package:rido_passenger/router/routes.dart';
import 'package:rido_passenger/state/ride_flow.dart';

import 'support/harness.dart';

void main() {
  testWidgets('P-15 shows the free waiting minutes left', (tester) async {
    await pumpRoute(tester, Routes.galleryView('P-15'));
    expect(find.text('Free waiting · 2:45 left'), findsOneWidget);
    expect(find.text('Then ₹1/min, up to ₹30'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  test('the ride flow times waiting from arrival on the booked fare\'s terms', () {
    final at = DateTime(2026, 9, 28, 10);
    const state = RideFlowState();
    expect(state.waiting, isNull);
    final w = state.copyWith(arrivedAt: at).waiting!;
    expect([w.freeMin, w.perMin, w.maxCharge], [3, 1, 30]);
    expect(w.chargeAt(at.add(const Duration(minutes: 5, seconds: 30))), 3);
  });

  test('P-22 keeps the waiting line as charged and still adds up to the fare', () {
    final q = FareEngine.withWaiting(FareEngine.quote(Seed.bike, const RouteEstimate(distanceKm: 4.2, durationMin: 14)), 3);
    final trip = Trip(
      id: 't1',
      kind: TripKind.ride,
      vehicle: VehicleKind.bike,
      pickup: Seed.gandhipuram,
      drop: Seed.brookefields,
      fare: 38,
      status: TripStatus.completed,
      startedAt: DateTime(2026, 9, 28, 10),
      quote: q,
    );
    final shown = P22TripDetailsScreen.quoteFor(trip);
    expect(shown.waitingCharge, 3);
    expect(shown.peakCharge, 0);
    expect(shown.subtotal + shown.peakCharge + shown.waitingCharge, 38);
  });

  test('P-22 keeps an earlier cancellation fee as its own line', () {
    final base = FareEngine.quote(Seed.bike, const RouteEstimate(distanceKm: 4.2, durationMin: 14));
    final q = base.copyWith(previousCancellationFee: 10, total: base.total + 10);
    final trip = Trip(
      id: 't2',
      kind: TripKind.ride,
      vehicle: VehicleKind.bike,
      pickup: Seed.gandhipuram,
      drop: Seed.brookefields,
      fare: 45,
      status: TripStatus.completed,
      startedAt: DateTime(2026, 9, 28, 10),
      quote: q,
    );
    final shown = P22TripDetailsScreen.quoteFor(trip);
    expect([shown.previousCancellationFee, shown.peakCharge, shown.total], [10, 0, 45]);
  });
}
