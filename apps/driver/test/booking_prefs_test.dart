import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';
import 'package:tamiltaxi_driver/features/account/booking_preferences_screen.dart';
import 'package:tamiltaxi_driver/state/booking_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/harness.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('summary and JSON of the preferences', () {
    const none = BookingPrefs();
    expect(none.hasFilters, isFalse);
    expect(none.toJson(), {'maxPickupKm': null, 'minTripKm': null, 'maxTripKm': null, 'goTo': null});

    const prefs = BookingPrefs(
      maxPickupKm: 2,
      minTripKm: 5,
      maxTripKm: 15,
      goTo: GoToDestination(location: LatLng(11.08, 77), name: 'Home'),
    );
    expect(prefs.summary, 'going to Home · pickup ≤ 2 km · trips 5–15 km');
    expect(const BookingPrefs(minTripKm: 5).summary, 'trips over 5 km');
    expect(const BookingPrefs(maxTripKm: 2.5).summary, 'trips under 2.5 km');

    final back = BookingPrefs.fromJson({
      'maxPickupKm': 2,
      'minTripKm': null,
      'maxTripKm': 15,
      'goTo': {'lat': 11.08, 'lng': 77, 'name': 'Home', 'until': '2026-09-29T12:00:00Z'},
    });
    expect(back.maxPickupKm, 2);
    expect(back.minTripKm, isNull);
    expect(back.goTo!.until, isNotNull);
  });

  testWidgets('set the farthest pickup and a minimum trip length, then save', (tester) async {
    final container = await pumpRoute(tester, '/account/booking-preferences');
    expect(find.byType(BookingPreferencesScreen), findsOneWidget);
    expect(find.text('Any distance'), findsOneWidget);
    expect(find.text('Save my location as Home'), findsOneWidget);

    // Go home needs a saved Home: its switch is off and disabled.
    final goHome = tester.widgetList<Switch>(find.byType(Switch)).last;
    expect(goHome.onChanged, isNull);

    await tester.tap(find.byTooltip('More').first);
    await tester.pump();
    expect(find.text('1.0 km max'), findsOneWidget);
    await tester.tap(find.byTooltip('More').first);
    await tester.pump();
    expect(find.text('1.5 km max'), findsOneWidget);

    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    expect(find.text('5.0 km'), findsOneWidget);

    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pump(const Duration(milliseconds: 300));
    final saved = container.read(bookingPrefsProvider).value!;
    expect(saved.maxPickupKm, 1.5);
    expect(saved.minTripKm, 5);
    expect(saved.maxTripKm, isNull);
    await tester.pump(const Duration(seconds: 5)); // snack
  });

  testWidgets('with a saved Home, Go home can be switched on', (tester) async {
    SharedPreferences.setMockInitialValues({'goto_home_lat': 11.08, 'goto_home_lng': 77.0});
    final container = await pumpRoute(tester, '/account/booking-preferences');
    await tester.pump();
    expect(find.text('Update Home to my location'), findsOneWidget);
    await tester.tap(find.byType(Switch).last);
    await tester.pump();
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(container.read(bookingPrefsProvider).value!.goTo?.name, 'Home');
    await tester.pump(const Duration(seconds: 5));
  });
}
