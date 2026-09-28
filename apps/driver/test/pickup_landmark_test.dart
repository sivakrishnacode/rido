// The rider's pickup landmark ("Near KG Hospital", from Google's address descriptors) on the request card and D-16.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_driver/features/jobs/widgets/request_layout.dart';
import 'package:rido_ui/rido_ui.dart';

import 'support/harness.dart';

const _offer = {
  'trip': {
    'id': 't1',
    'kind': 'RIDE',
    'status': 'SEARCHING',
    'vehicleKind': 'BIKE',
    'pickupName': 'Ondipudur',
    'pickupAddr': 'Trichy Rd, Ondipudur',
    'pickupLandmark': 'Near KG Hospital',
    'pickupLat': 10.98085,
    'pickupLng': 77.04175,
    'dropName': 'Ukkadam',
    'dropAddr': 'Ukkadam',
    'dropLat': 10.98833,
    'dropLng': 76.96269,
    'fareTotal': 120,
    'distanceKm': 11.4,
    'durationMin': 38,
    'createdAt': '2026-09-28T05:31:00.000Z',
  },
  'passenger': {'name': 'Priya', 'phone': '+919000000002'},
  'pickupKm': 0.8,
  'pickupEtaMin': 3,
};

Future<void> _pumpRoute(WidgetTester tester, RideRequest r) async {
  await loadTestFonts();
  usePhone(tester);
  await tester.pumpWidget(MaterialApp(
    theme: RidoTheme.light(),
    home: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: RequestRoute(request: r))),
  ));
}

void main() {
  testWidgets('the request card shows where to meet the rider', (tester) async {
    final r = rideRequestFromOffer(_offer);
    expect(r.pickup.landmark, 'Near KG Hospital');
    await _pumpRoute(tester, r);
    expect(find.text('Near KG Hospital · 0.8 km away · 3 min'), findsOneWidget);
  });

  testWidgets('a trip booked without a landmark (older app) shows the distance only', (tester) async {
    final trip = Map<String, dynamic>.of(_offer['trip']! as Map<String, dynamic>)..remove('pickupLandmark');
    final r = rideRequestFromOffer({..._offer, 'trip': trip});
    expect(r.pickup.landmark, isNull);
    await _pumpRoute(tester, r);
    expect(find.text('0.8 km away · 3 min'), findsOneWidget);
  });
}
