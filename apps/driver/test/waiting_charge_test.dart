import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';
import 'package:tamiltaxi_driver/router/routes.dart';
import 'package:tamiltaxi_driver/state/live_helpers.dart';

import 'support/harness.dart';

void main() {
  testWidgets('D-17 shows the waiting chip at the pickup', (tester) async {
    await pumpRoute(tester, Routes.galleryView('D-17'));
    expect(find.text('Free waiting · 2:45 left'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('D-23b lists the waiting charge of a trip', (tester) async {
    await pumpRoute(tester, Routes.galleryView('D-23b'));
    expect(find.text('Waiting charge'), findsOneWidget);
    expect(find.text('+₹3'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  test('the waiting timer comes from arrivedAt and the fare terms of the trip', () {
    final json = {
      'id': 't1',
      'kind': 'RIDE',
      'status': 'DRIVER_ARRIVED',
      'vehicleKind': 'CAB',
      'fareTotal': 132,
      'arrivedAt': '2026-09-28T04:30:00.000Z',
      'fare': {'vehicleKind': 'CAB', 'total': 132, 'freeWaitMin': 4, 'waitPerMin': 2, 'waitMaxCharge': 25},
    };
    final w = waitingOf(LiveTripUpdate(tripFromJson(json), 'DRIVER_ARRIVED', json))!;
    expect([w.freeMin, w.perMin, w.maxCharge], [4, 2, 25]);
    expect(w.arrivedAt, DateTime.utc(2026, 9, 28, 4, 30).toLocal());
    final notYet = {...json}..remove('arrivedAt');
    expect(waitingOf(LiveTripUpdate(tripFromJson(notYet), 'DRIVER_ASSIGNED', notYet)), isNull);
  });
}
