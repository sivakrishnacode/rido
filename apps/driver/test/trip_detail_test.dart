// D-23b shows only what the trip record has: the real places and a reference from the trip id, no city code, no
// made-up ratings.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';
import 'package:tamiltaxi_driver/features/earnings/d23b_trip_detail_sheet.dart';
import 'package:tamiltaxi_ui/tamiltaxi_ui.dart';

import 'support/harness.dart';

final _trip = EarningsTrip(
  id: 'cm1x9k3f9q2xa',
  time: DateTime(2026, 10, 3, 18, 40),
  from: 'Gandhi Park',
  to: 'Town Hall',
  fare: 64,
  paymentMode: PaymentMode.upi,
  distanceKm: 6.2,
  durationMin: 21,
  passengerName: 'Meena',
);

void main() {
  test('the reference comes from the trip id', () {
    expect(D23bTripDetailSheet.tripCode(_trip), '#K3F9Q2XA');
  });

  testWidgets('live: real names, no city code, no ratings', (tester) async {
    await loadTestFonts();
    usePhone(tester);
    await tester.pumpWidget(ProviderScope(
      overrides: [isLiveApiProvider.overrideWithValue(true)],
      child: RepaintBoundary(
        key: shotKey,
        child: MaterialApp(
          theme: TtTheme.light(),
          home: Scaffold(body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: D23bTripDetailSheet(trip: _trip))),
        ),
      ),
    ));
    await tester.pump();
    expect(find.text('Gandhi Park'), findsOneWidget);
    expect(find.text('Town Hall'), findsOneWidget);
    expect(find.textContaining('TT-CBE'), findsNothing);
    expect(find.textContaining('#K3F9Q2XA'), findsOneWidget);
    expect(find.textContaining('★'), findsNothing);
    expect(find.text('Meena'), findsOneWidget);
    // The profile load (demo latency) finishes.
    await tester.pump(const Duration(seconds: 3));
  });
}
