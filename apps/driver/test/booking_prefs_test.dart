import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';
import 'package:tamiltaxi_driver/features/account/booking_preferences_screen.dart';
import 'package:tamiltaxi_driver/features/home/widgets/direction_panel.dart';
import 'package:tamiltaxi_driver/state/booking_prefs.dart';
import 'package:tamiltaxi_driver/state/driver_account.dart';
import 'package:tamiltaxi_ui/tamiltaxi_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/harness.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  const home = SavedArea(name: 'Home', location: LatLng(11.08, 77));

  /// Scrolls [f] to the middle (the Save bar and snacks cover the bottom edge) before a tap.
  Future<void> center(WidgetTester tester, Finder f) async {
    await Scrollable.ensureVisible(tester.element(f), alignment: 0.5);
    await tester.pump();
  }

  test('summary and JSON of the preferences', () {
    const none = BookingPrefs();
    expect(none.hasFilters, isFalse);
    expect(none.toJson(), {
      'maxPickupKm': null,
      'minTripKm': null,
      'maxTripKm': null,
      'goTo': null,
      'stayIn': null,
      'parcels': true,
      'areas': <Object>[],
      'shifting': false,
      'helpers': 2,
    });

    const prefs = BookingPrefs(
      maxPickupKm: 2,
      minTripKm: 5,
      maxTripKm: 15,
      goTo: GoToDestination(location: LatLng(11.08, 77), name: 'Home'),
    );
    expect(prefs.summary, 'going to Home · pickup ≤ 2 km · trips 5–15 km');
    expect(prefs.tripFilterSummary, 'pickup ≤ 2 km · trips 5–15 km');
    expect(const BookingPrefs(minTripKm: 5).summary, 'trips over 5 km');
    expect(const BookingPrefs(maxTripKm: 2.5).summary, 'trips under 2.5 km');

    final back = BookingPrefs.fromJson({
      'maxPickupKm': 2,
      'minTripKm': null,
      'maxTripKm': 15,
      'goTo': {'lat': 11.08, 'lng': 77, 'name': 'Home', 'until': '2026-09-29T12:00:00Z'},
      'parcels': false,
      'areas': [
        {'name': 'Home', 'lat': 11.08, 'lng': 77},
        {'name': 'Broken'},
      ],
    });
    expect(back.maxPickupKm, 2);
    expect(back.minTripKm, isNull);
    expect(back.goTo!.until, isNotNull);
    expect(back.parcels, isFalse);
    expect(back.areas, [home]);
    // An older server: no parcels field means parcels on.
    expect(BookingPrefs.fromJson(const {}).parcels, isTrue);
    // House shifting: off unless switched on; helpers within 0–8.
    expect(BookingPrefs.fromJson(const {}).shifting, isFalse);
    final mover = BookingPrefs.fromJson(const {'shifting': true, 'helpers': 12});
    expect((mover.shifting, mover.helpers), (true, 8));
    expect(const BookingPrefs(shifting: true, helpers: 3).summary, 'Packers & Movers with 3 helpers');
  });

  test('Go To and Stay In are never on together', () {
    final stay = const BookingPrefs().stayingIn(home, radiusKm: 8);
    expect(stay.stayIn?.radiusKm, 8);
    expect(stay.hasDirection, isTrue);
    expect(stay.toJson()['stayIn'], {'lat': 11.08, 'lng': 77.0, 'name': 'Home', 'radiusKm': 8.0});
    final go = stay.goingTo(home);
    expect(go.goTo?.name, 'Home');
    expect(go.stayIn, isNull);
    expect(go.goingTo(null).hasDirection, isFalse);
    expect(StayInArea.fromJson({'lat': 11, 'lng': 77, 'name': 'X', 'radiusKm': 5, 'until': '2026-09-29T20:00:00Z'})!.until, isNotNull);
  });

  test('the request card tag follows what is on, until its time is up', () {
    final now = DateTime(2026, 9, 30, 10);
    final going = BookingPrefs(goTo: GoToDestination(location: home.location, name: 'Home', until: now.add(const Duration(hours: 1))));
    expect(directionTag(going, now), 'Towards Home');
    expect(directionTag(going, now.add(const Duration(hours: 2))), isNull);
    final staying = BookingPrefs(stayIn: StayInArea(location: home.location, name: 'RS Puram', radiusKm: 5));
    expect(directionTag(staying, now), 'Inside RS Puram');
    expect(directionTag(const BookingPrefs(), now), isNull);
  });

  testWidgets('set the farthest pickup, a minimum trip length and parcels off, then save', (tester) async {
    final container = await pumpRoute(tester, '/account/booking-preferences');
    expect(find.byType(BookingPreferencesScreen), findsOneWidget);
    expect(find.text('Any distance'), findsOneWidget);
    expect(find.text('Go To / Stay In'), findsOneWidget);
    // The demo driver rides a bike: parcels too, on by default.
    expect(find.text('Parcels too'), findsOneWidget);

    await tester.tap(find.byTooltip('More').first);
    await tester.pump();
    expect(find.text('1.0 km max'), findsOneWidget);
    await tester.tap(find.byTooltip('More').first);
    await tester.pump();
    expect(find.text('1.5 km max'), findsOneWidget);

    await center(tester, find.byType(Checkbox).first);
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    expect(find.text('5.0 km'), findsOneWidget);

    await center(tester, find.text('Parcels too'));
    await tester.tap(find.byType(Switch).last);
    await tester.pump();

    await center(tester, find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pump(const Duration(milliseconds: 300));
    final saved = container.read(bookingPrefsProvider).value!;
    expect(saved.maxPickupKm, 1.5);
    expect(saved.minTripKm, 5);
    expect(saved.maxTripKm, isNull);
    expect(saved.parcels, isFalse);
    await tester.pump(const Duration(seconds: 5)); // snack
  });

  testWidgets('a goods-truck driver switches house shifting on and says how many helpers they bring', (tester) async {
    final container = await pumpRoute(tester, '/account/booking-preferences', overrides: [driverProfileProvider.overrideWith(_Mover.new)]);
    expect(find.text('Parcels too'), findsNothing, reason: 'bikes only');
    await center(tester, find.text('Packers & Movers jobs'));
    expect(find.text('Helpers you bring'), findsNothing);
    await tester.tap(find.byType(Switch).last);
    await tester.pump();
    await center(tester, find.text('Helpers you bring'));
    expect(find.text('Moves needing up to 2. The customer pays for them in the price.'), findsOneWidget);
    await tester.tap(find.byTooltip('More helpers'));
    await tester.pump();
    expect(find.text('Moves needing up to 3. The customer pays for them in the price.'), findsOneWidget);

    await center(tester, find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pump(const Duration(milliseconds: 300));
    final saved = container.read(bookingPrefsProvider).value!;
    expect((saved.shifting, saved.helpers), (true, 3));
    await tester.pump(const Duration(seconds: 5)); // snack
  });

  testWidgets('a bike driver has no house shifting', (tester) async {
    await pumpRoute(tester, '/account/booking-preferences');
    expect(find.text('Packers & Movers jobs', skipOffstage: false), findsNothing);
  });

  testWidgets('add an area, turn Go To on, then Stay In there within 8 km (Go To goes off)', (tester) async {
    final container = await pumpRoute(tester, '/account/booking-preferences');
    await tester.tap(find.text('Go To / Stay In'));
    await tester.pumpAndSettle();
    expect(find.text('Where do you want trips?'), findsOneWidget);
    expect(find.text('Save a place you often go to, like Home or your stand.'), findsOneWidget);
    // Nothing picked yet: nothing to turn on.
    expect(tester.widget<TtButton>(find.widgetWithText(TtButton, 'Turn on Go To')).onPressed, isNull);

    await tester.tap(find.text('Add area'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Brookefields');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Brookefields Mall').first);
    await tester.pumpAndSettle();

    // Back on the sheet: the new area is saved and picked.
    expect(container.read(bookingPrefsProvider).value!.areas.map((a) => a.name), ['Brookefields Mall']);
    await center(tester, find.widgetWithText(TtButton, 'Turn on Go To'));
    await tester.tap(find.widgetWithText(TtButton, 'Turn on Go To'));
    await tester.pumpAndSettle();
    expect(container.read(bookingPrefsProvider).value!.goTo?.name, 'Brookefields Mall');
    expect(find.text('Going to Brookefields Mall'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5)); // the snack goes
    await tester.pumpAndSettle();

    await tester.tap(find.text('Go To / Stay In'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stay In').first);
    await tester.pump();
    await tester.tap(find.text('Brookefields Mall').last);
    await center(tester, find.text('8 km'));
    await tester.tap(find.text('8 km'));
    await tester.pump();
    expect(find.text('Go To (Brookefields Mall) turns off.'), findsOneWidget);
    await center(tester, find.widgetWithText(TtButton, 'Turn on Stay In'));
    await tester.tap(find.widgetWithText(TtButton, 'Turn on Stay In'));
    await tester.pumpAndSettle();
    final prefs = container.read(bookingPrefsProvider).value!;
    expect(prefs.goTo, isNull);
    expect(prefs.stayIn?.radiusKm, 8);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('request screen bar: Set when nothing is on, what is on with Change, both open the sheet', (tester) async {
    await loadTestFonts();
    usePhone(tester);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(bookingPrefsProvider.future);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: TtTheme.light(), home: const Scaffold(body: Center(child: RequestDirectionBar()))),
    ));
    await tester.pump();
    expect(find.text('Go To or Stay In'), findsOneWidget);
    expect(find.text('Set'), findsOneWidget);

    await container.read(bookingPrefsProvider.notifier).save(const BookingPrefs().stayingIn(home, radiusKm: 5));
    await tester.pump();
    expect(find.text('Inside Home'), findsOneWidget);
    expect(find.text('Change'), findsOneWidget);
    await tester.tap(find.byType(RequestDirectionBar));
    await tester.pumpAndSettle();
    expect(find.text('Where do you want trips?'), findsOneWidget);
    expect(find.widgetWithText(TtButton, 'Turn Stay In off'), findsOneWidget);
  });

  testWidgets('Home strip: what is on, and ✕ turns it off', (tester) async {
    await loadTestFonts();
    usePhone(tester);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(bookingPrefsProvider.future);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: TtTheme.light(), home: const Scaffold(body: Center(child: DirectionRow()))),
    ));
    await tester.pump();
    expect(find.text('Go To'), findsOneWidget);
    expect(find.text('Stay In'), findsOneWidget);

    await container.read(bookingPrefsProvider.notifier).save(const BookingPrefs().stayingIn(home, radiusKm: 3));
    await tester.pump();
    expect(find.text('Staying in Home'), findsOneWidget);
    expect(find.text('Only trips within 3 km'), findsOneWidget);

    await tester.tap(find.byTooltip('Turn Stay In off'));
    await tester.pump();
    expect(container.read(bookingPrefsProvider).value!.hasDirection, isFalse);
    expect(find.text('Go To'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });
}

/// The demo goods driver (a three-wheeler) instead of the bike driver.
class _Mover extends DriverProfileController {
  @override
  Future<DriverProfile> build() async => Seed.selvam;
}
