import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

void main() {
  final arrived = DateTime(2026, 9, 28, 10);
  final terms = WaitingTerms(arrivedAt: arrived, freeMin: 3, perMin: 2, maxCharge: 30);

  test('free minutes count down, then the charge adds up to the cap', () {
    final free = waitingLabel(terms, arrived.add(const Duration(seconds: 15)));
    expect(free.title, 'Free waiting · 2:45 left');
    expect(free.detail, 'Then ₹2/min, up to ₹30');
    expect(free.isCharging, isFalse);

    final paying = waitingLabel(terms, arrived.add(const Duration(minutes: 5, seconds: 30)));
    expect(paying.title, 'Waiting charge ₹6');
    expect(paying.isCharging, isTrue);

    expect(waitingLabel(terms, arrived.add(const Duration(hours: 1))).detail, 'Maximum reached');
    expect(waitingLabel(WaitingTerms(arrivedAt: arrived, perMin: 0), arrived).detail, 'No waiting charge');
  });

  testWidgets('the chip shows the charging state', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: RidoTheme.light(),
      home: Scaffold(body: WaitingTimerChip(terms: terms, clock: () => arrived.add(const Duration(minutes: 4)))),
    ));
    expect(find.text('Waiting charge ₹2'), findsOneWidget);
    expect(find.text('₹2 per started minute, up to ₹30'), findsOneWidget);
  });

  test('the fare breakdown has a waiting line only when there is a charge', () {
    final q = FareEngine.quote(Seed.bike, const RouteEstimate(distanceKm: 4.2, durationMin: 14));
    List<String> labels(FareQuote q) => [for (final l in FareBreakdown.fromQuote(q).lines) l.label];
    expect(labels(q), isNot(contains('Waiting charge')));
    final waited = FareEngine.withWaiting(q, 3);
    expect(labels(waited), contains('Waiting charge'));
    expect(FareBreakdown.fromQuote(waited).total, 38);
  });

  test('a previous cancellation fee is its own line, only when there is one', () {
    final q = FareEngine.quote(Seed.bike, const RouteEstimate(distanceKm: 4.2, durationMin: 14));
    List<String> labels(FareQuote q) => [for (final l in FareBreakdown.fromQuote(q).lines) l.label];
    expect(labels(q), isNot(contains('Previous cancellation fee')));
    final withFee = q.copyWith(previousCancellationFee: 10, total: q.total + 10);
    expect(labels(withFee), contains('Previous cancellation fee'));
  });
}
