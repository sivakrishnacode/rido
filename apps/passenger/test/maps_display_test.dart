// What the passenger sees from Google Maps data: travel time (traffic) vs the fare's minutes on P-10 / P-11.
import 'package:flutter_test/flutter_test.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_passenger/features/ride/p11_fare_details_sheet.dart';
import 'package:rido_passenger/router/routes.dart';
import 'package:rido_ui/rido_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/harness.dart';

/// Server quotes for 11.4 km: 38 fare minutes (18 km/h), 24 minutes by Google's traffic-aware route.
class _TrafficRides extends MockRideRepository {
  _TrafficRides(super.db, super.settings, {this.travelMin});
  final int? travelMin;

  @override
  Future<List<FareQuote>> quotes(Place from, Place to, {bool womenOnly = false}) async => [
        for (final q in FareEngine.quoteAll(rideVehicles, const RouteEstimate(distanceKm: 11.4, durationMin: 38)))
          FareQuote(
            vehicle: q.vehicle,
            distanceKm: q.distanceKm,
            durationMin: q.durationMin,
            travelMin: travelMin,
            base: q.base,
            distanceCharge: q.distanceCharge,
            timeCharge: q.timeCharge,
            subtotal: q.subtotal,
            multiplier: q.multiplier,
            peakCharge: q.peakCharge,
            total: q.total,
            pickupEtaMin: 3,
          ),
      ];
}

Future<void> _openP10(WidgetTester tester, {int? travelMin}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await tester.runAsync(SharedPreferences.getInstance);
  // No server: calls to it fail at once; the fares come from the fake repository.
  final api = ApiClient(baseUrl: 'http://localhost:0/v1', session: ApiSession(prefs!));
  await pumpRoute(tester, Routes.chooseVehicle, overrides: [
    isLiveApiProvider.overrideWithValue(true),
    apiClientProvider.overrideWithValue(api),
    rideRepositoryProvider.overrideWith(
      (ref) => _TrafficRides(ref.watch(mockDatabaseProvider), () => ref.read(demoSettingsProvider), travelMin: travelMin),
    ),
  ]);
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets("P-10's route chip and drop time use Google's travel minutes; the fare keeps its own", (tester) async {
    await _openP10(tester, travelMin: 24);
    expect(find.text('11.4 km · 24 min'), findsOneWidget);
    // Pickup in 3 min + 24 min on the road, not 3 + 38 fare minutes.
    final drop = formatTime(RidoClock.now().add(const Duration(minutes: 27)));
    expect(find.text('3 min away · Drop $drop'), findsWidgets);

    await tester.tap(find.text('Fare details'));
    await tester.pumpAndSettle();
    expect(find.byType(P11FareDetailsSheet), findsOneWidget);
    expect(find.textContaining('38 min at 18 km/h'), findsOneWidget);
  });

  testWidgets('without travel minutes (older server, no Google key) P-10 shows the fare minutes', (tester) async {
    await _openP10(tester);
    expect(find.text('11.4 km · 38 min'), findsOneWidget);
  });
}
