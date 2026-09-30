import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';
import 'package:tamiltaxi_driver/features/jobs/widgets/request_stack_view.dart';
import 'package:tamiltaxi_ui/tamiltaxi_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/harness.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pump(WidgetTester tester, List<StackEntry> entries,
      {ValueChanged<String>? onAccept, ValueChanged<String>? onDecline, String? acceptingId, String? direction}) async {
    await loadTestFonts();
    usePhone(tester);
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        theme: TtTheme.light(),
        home: RequestStackView(
          entries: entries,
          acceptingId: acceptingId,
          direction: direction,
          onAccept: onAccept ?? (_) {},
          onDecline: onDecline ?? (_) {},
          onExpired: (_) {},
        ),
      ),
    ));
    await tester.pump();
  }

  List<StackEntry> three() {
    final now = DateTime.now();
    return [
      (request: Seed.rideRequest.copyWith(id: 'late', fare: 253, tripKm: 11), expiresAt: now.add(const Duration(seconds: 14))),
      (request: Seed.rideRequest.copyWith(id: 'soon', fare: 202, tripKm: 8), expiresAt: now.add(const Duration(seconds: 6))),
      (request: Seed.rideRequest.copyWith(id: 'mid', fare: 217, tripKm: 7), expiresAt: now.add(const Duration(seconds: 10))),
    ];
  }

  testWidgets('every open request is a card with fare and ₹/km, soonest to close first, and a rail entry', (tester) async {
    await pump(tester, three());
    expect(find.text('3 ride requests'), findsOneWidget);
    // Fare on the rail and on the card.
    expect(find.text('₹202'), findsNWidgets(2));
    expect(find.text('₹25/km'), findsOneWidget); // 202 / 8
    expect(find.text('Swipe to accept'), findsNWidgets(3));
    final cards = tester.widgetList<Padding>(find.byWidgetPredicate((w) => w is Padding && w.key is GlobalKey)).toList();
    expect(cards, hasLength(3));
    final soonY = tester.getTopLeft(find.byKey(const ValueKey('card-soon'))).dy;
    final lateY = tester.getTopLeft(find.byKey(const ValueKey('card-late'))).dy;
    expect(soonY, lessThan(lateY));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets("the rider's extra shows as ₹50 + ₹20 with its own line; Go To tags every card", (tester) async {
    final now = DateTime.now();
    await pump(tester, [
      (request: Seed.rideRequest.copyWith(id: 'boosted', fare: 70, extra: 20, tripKm: 5), expiresAt: now.add(const Duration(seconds: 9))),
    ], direction: 'Towards Home');
    expect(find.text('₹50 + ₹20'), findsOneWidget);
    expect(find.text('Rider added ₹20 extra'), findsOneWidget);
    expect(find.text('₹14/km'), findsOneWidget); // 70 / 5: on what the driver collects
    expect(find.text('Towards Home'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a bike driver\'s stack of rides and parcels is titled by both', (tester) async {
    final now = DateTime.now();
    await pump(tester, [
      (request: Seed.rideRequest.copyWith(id: 'ride'), expiresAt: now.add(const Duration(seconds: 9))),
      (request: Seed.deliveryRequest.copyWith(id: 'parcel', extra: 10), expiresAt: now.add(const Duration(seconds: 12))),
    ]);
    expect(find.text('2 requests'), findsOneWidget);
    expect(find.text('Sender added ₹10 extra'), findsOneWidget);
    // The rail shows the fare without the extra and the extra under it.
    expect(find.text('+₹10'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('swipe accepts that card; ✕ declines that card', (tester) async {
    String? accepted;
    String? declined;
    await pump(tester, three(), onAccept: (id) => accepted = id, onDecline: (id) => declined = id);
    await tester.drag(find.byKey(const ValueKey('swipe-knob')).first, const Offset(600, 0));
    await tester.pump(const Duration(milliseconds: 300));
    expect(accepted, 'soon');
    await tester.tap(find.bySemanticsLabel('Decline ₹217 request'));
    expect(declined, 'mid');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('while one is being accepted the others are locked', (tester) async {
    await pump(tester, three(), acceptingId: 'soon');
    expect(find.text('Accepting'), findsOneWidget);
    final swipes = tester.widgetList<SwipeToConfirm>(find.byType(SwipeToConfirm));
    expect(swipes.every((s) => !s.enabled), isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('each card shows the seconds left and counts down, red at the end', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: TtTheme.light(),
      home: const Scaffold(body: Center(child: SecondsLeft(left: Duration(seconds: 7)))),
    ));
    expect(find.text('7s'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    final label = find.text('4s');
    expect(label, findsOneWidget);
    expect(tester.widget<Text>(label).style?.color, TtColors.error);
    await tester.pumpWidget(const SizedBox());
  });
}
