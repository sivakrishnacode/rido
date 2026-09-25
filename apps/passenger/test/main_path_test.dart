// Main passenger path, end to end with fast mode and fake time:
// Home → search "Brook" → Brookefields Mall → Book Bike · ₹38 → driver found → arrives →
// ride starts → arrived → rate → back Home, and the ride is at the top of Activity.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_passenger/features/ride/p13_driver_assigned_screen.dart';
import 'package:rido_passenger/features/ride/p15_driver_arrived_screen.dart';
import 'package:rido_passenger/features/ride/p16_ride_in_progress_screen.dart';
import 'package:rido_passenger/features/ride/p19_ride_completed_screen.dart';
import 'package:rido_passenger/features/ride/p20_rate_driver_screen.dart';
import 'package:rido_passenger/router/routes.dart';
import 'package:rido_passenger/state/passenger_session.dart';
import 'package:rido_passenger/state/ride_flow.dart';
import 'package:rido_ui/rido_ui.dart';

import 'support/harness.dart';

/// Pumps in small steps so timers, animations and navigation all advance.
Future<void> advance(WidgetTester tester, Duration total, {Duration step = const Duration(milliseconds: 100)}) async {
  var elapsed = Duration.zero;
  while (elapsed < total) {
    await tester.pump(step);
    elapsed += step;
  }
}

/// Advances time until [finder] shows up (fails after [timeout]).
Future<void> waitFor(WidgetTester tester, Finder finder, {Duration timeout = const Duration(seconds: 20)}) async {
  var waited = Duration.zero;
  while (finder.evaluate().isEmpty) {
    if (waited >= timeout) fail('Timed out waiting for $finder');
    await tester.pump(const Duration(milliseconds: 100));
    waited += const Duration(milliseconds: 100);
  }
}

void main() {
  testWidgets('passenger books a bike ride Gandhipuram → Brookefields through to rating', (tester) async {
    final container = await pumpRoute(tester, Routes.ride);
    container.read(demoSettingsProvider.notifier).update((s) => s.copyWith(fastMode: true));
    await advance(tester, const Duration(seconds: 2));

    // P-07 → P-08
    await tester.tap(find.byType(SearchField).first);
    await advance(tester, const Duration(seconds: 1));

    // P-08: type "Brook" and pick Brookefields Mall.
    await tester.enterText(find.byType(TextField).hitTestable().last, 'Brook');
    await waitFor(tester, find.text('Brookefields Mall'));
    await advance(tester, const Duration(milliseconds: 500));
    await tester.tap(find.text('Brookefields Mall').hitTestable().first);
    await advance(tester, const Duration(seconds: 1));

    // P-10: Bike is selected by default; fare is ₹38.
    final book = find.text('Book Bike · ₹38');
    expect(book, findsOneWidget);
    expect(container.read(rideFlowProvider).drop, Seed.brookefields);
    await tester.tap(book);
    await advance(tester, const Duration(milliseconds: 300));
    expect(container.read(rideFlowProvider).phase, RidePhase.searching);

    // The simulated backend takes it from here.
    await waitFor(tester, find.byType(P13DriverAssignedScreen));
    expect(container.read(rideFlowProvider).driver.name, 'Karthik S');
    await waitFor(tester, find.byType(P15DriverArrivedScreen));
    await waitFor(tester, find.byType(P16RideInProgressScreen));
    await waitFor(tester, find.byType(P19RideCompletedScreen), timeout: const Duration(seconds: 30));
    expect(find.text('₹38'), findsWidgets);

    // P-19 → P-20 → Submit.
    await tester.tap(find.text('Done, rate your ride'));
    await waitFor(tester, find.byType(P20RateDriverScreen));
    await tester.tap(find.text('Submit'));
    await advance(tester, const Duration(seconds: 2));

    expect(container.read(rideFlowProvider).phase, RidePhase.planning);
    // Repositories use Future.delayed, so pump fake time until the history loads.
    container.listen(tripHistoryProvider, (_, _) {});
    await advance(tester, const Duration(seconds: 2));
    final history = container.read(tripHistoryProvider).requireValue;
    expect(history.first.status, TripStatus.completed);
    expect(history.first.fare, 38);
    expect(history.first.drop, Seed.brookefields);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 1));
  }, timeout: const Timeout(Duration(minutes: 3)));
}
