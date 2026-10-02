// P-17 SOS in live API mode: the SOS goes to the server first; offline it falls back to the phone (112, SMS with the
// live link or a maps link).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';
import 'package:tamiltaxi_passenger/features/ride/p15_driver_arrived_screen.dart';
import 'package:tamiltaxi_passenger/features/ride/p17_sos_screen.dart';
import 'package:tamiltaxi_passenger/router/routes.dart';
import 'package:tamiltaxi_passenger/state/ride_flow.dart';
import 'package:tamiltaxi_ui/tamiltaxi_ui.dart';

import 'support/fake_safety.dart';
import 'support/harness.dart';

class _FixedRide extends RideFlowController {
  _FixedRide(this.initial);
  final RideFlowState initial;
  @override
  RideFlowState build() => initial;

  /// What a trip update does to the flow.
  void moveTo(RidePhase phase) => state = state.copyWith(phase: phase);
}

final _ride = RideFlowState(phase: RidePhase.inProgress, tripId: 'trip1', route: [Seed.gandhipuram.location, Seed.brookefields.location]);

Future<void> _pump(WidgetTester tester, FakeSafety safety, {RideFlowState? ride}) async {
  await loadTestFonts();
  usePhone(tester);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      isLiveApiProvider.overrideWithValue(true),
      liveSafetyProvider.overrideWithValue(safety),
      rideFlowProvider.overrideWith(() => _FixedRide(ride ?? _ride)),
    ],
    child: MaterialApp(theme: TtTheme.light(), home: const P17SosScreen()),
  ));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pump();
}

void main() {
  testWidgets('opening SOS during a trip alerts the Tamil Taxi safety team through the API', (tester) async {
    final safety = FakeSafety();
    await _pump(tester, safety);
    expect(safety.sosCalls.map((c) => c.tripId), ['trip1']);
    expect(find.text('Tamil Taxi safety team has been alerted'), findsOneWidget);
    expect(find.text('Call 112'), findsOneWidget);
  });

  testWidgets('offline: says so, keeps Call 112 and texting, and Try again sends it', (tester) async {
    final safety = FakeSafety(failSos: true);
    await _pump(tester, safety);
    expect(find.text("Couldn't reach Tamil Taxi"), findsOneWidget);
    expect(find.text('Call 112'), findsOneWidget);

    safety.failSos = false;
    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.pump();
    expect(safety.sosCalls, hasLength(2));
    expect(find.text('Tamil Taxi safety team has been alerted'), findsOneWidget);
  });

  testWidgets('no active trip: nothing to raise it on, the phone options stay', (tester) async {
    final safety = FakeSafety();
    await _pump(tester, safety, ride: const RideFlowState());
    expect(safety.sosCalls, isEmpty);
    expect(find.text('Call 112'), findsOneWidget);
  });

  group('sosSmsBody', () {
    const at = LatLng(11.01834, 76.97251);
    test('carries the live tracking link during a trip', () {
      final body = sosSmsBody(me: 'Priya', ride: _ride, at: at, liveUrl: 'https://admin.tamiltaxi.test/track/t1');
      expect(body, startsWith('SOS from Priya. I need help.'));
      expect(body, contains('Track live: https://admin.tamiltaxi.test/track/t1'));
      expect(body, isNot(contains('maps.google.com')));
    });

    test('falls back to a maps link without one', () {
      expect(sosSmsBody(me: 'Priya', ride: _ride, at: at), contains('https://maps.google.com/?q=11.01834,76.97251'));
      expect(sosSmsBody(me: 'Priya', ride: const RideFlowState(), at: at), 'SOS from Priya. I need help. My location: https://maps.google.com/?q=11.01834,76.97251');
      expect(sosSmsBody(me: 'Priya', ride: const RideFlowState(), at: null), 'SOS from Priya. I need help.');
    });
  });

  testWidgets('a trip update while SOS is open keeps SOS on screen; closing it shows where the ride is now', (tester) async {
    final ride = _FixedRide(RideFlowState(phase: RidePhase.assigned, tripId: 'trip1', driver: Seed.murugan));
    final container = await pumpRoute(tester, Routes.driverAssigned, overrides: [rideFlowProvider.overrideWith(() => ride)]);
    await tester.tap(find.bySemanticsLabel('SOS emergency help').first);
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.byType(P17SosScreen), findsOneWidget);

    // The driver arrives: SOS stays.
    (container.read(rideFlowProvider.notifier) as _FixedRide).moveTo(RidePhase.arrived);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(P17SosScreen), findsOneWidget);

    // Closing SOS opens the screen for the ride as it is now.
    await tester.tap(find.byTooltip('Close').first);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(P17SosScreen), findsNothing);
    expect(find.byType(P15DriverArrivedScreen), findsOneWidget);
  });
}
