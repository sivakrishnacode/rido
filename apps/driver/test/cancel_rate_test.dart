import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_driver/features/states/s10_account_on_hold_screen.dart';
import 'package:rido_driver/router/routes.dart';

import 'support/harness.dart';

void main() {
  test('the pause end reads as today, tomorrow or a date', () {
    final now = DateTime(2026, 9, 28, 10);
    expect(pausedUntilLabel(DateTime(2026, 9, 28, 15, 40), now), 'until 3:40 PM');
    expect(pausedUntilLabel(DateTime(2026, 9, 29, 15, 40), now), 'until 3:40 PM tomorrow');
    expect(pausedUntilLabel(DateTime(2026, 10, 1, 9, 5), now), 'until 9:05 AM, 1 Oct');
  });

  test('reads the rate, the banner text and the pause from the API', () {
    final r = DriverCancelRate.fromJson({
      'cancelled': 2,
      'assigned': 5,
      'rate': 0.4,
      'level': 'NUDGE',
      'blockedUntil': null,
      'message': {'title': "You've cancelled 2 of your last 5 rides", 'body': 'Only accept rides you can reach'},
    });
    expect([r.level, r.shouldWarn, r.isPausedAt(DateTime.now())], [CancelRateLevel.nudge, true, false]);
    final paused = DriverCancelRate.fromJson({'level': 'BLOCK', 'blockedUntil': DateTime.now().add(const Duration(hours: 1)).toUtc().toIso8601String()});
    expect(paused.isPausedAt(DateTime.now()), isTrue);
    expect(DriverCancelRate.fromJson({'level': 'OK'}).shouldWarn, isFalse);
  });

  testWidgets('S-17: Home warns about the cancellation rate', (tester) async {
    await pumpRoute(tester, Routes.galleryView('S-17'));
    expect(find.text("You've cancelled 2 of your last 5 rides"), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('S-10b: the pause screen says until when and why', (tester) async {
    final until = DateTime.now().add(const Duration(hours: 2));
    await pumpRoute(tester, Routes.accountPaused(until));
    expect(find.textContaining("You're paused until"), findsOneWidget);
    expect(find.text('Too many cancelled rides'), findsOneWidget);
    expect(find.text('Contact support'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
