import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rido_driver/features/jobs/widgets/no_show_button.dart';
import 'package:rido_ui/rido_ui.dart';

void main() {
  final now = DateTime(2026, 9, 28, 10);

  test('counts down to the no-show time, then offers the cancel', () {
    expect(noShowLabel(now.add(const Duration(minutes: 4, seconds: 5)), now), "Passenger didn't come? Cancel in 4:05");
    expect(noShowLabel(now, now), "Passenger didn't come? Cancel ride");
    expect(noShowLabel(null, now), contains('Wait at the pickup'));
  });

  Future<void> pump(WidgetTester tester, DateTime at, VoidCallback onCancel) => tester.pumpWidget(MaterialApp(
        theme: RidoTheme.light(),
        home: Scaffold(body: NoShowButton(noShowAt: at, onCancel: onCancel)),
      ));

  testWidgets('is off during the wait and on after it', (tester) async {
    var taps = 0;
    await pump(tester, DateTime.now().add(const Duration(minutes: 5)), () => taps++);
    await tester.tap(find.textContaining('Cancel in'));
    expect(taps, 0);
    await pump(tester, DateTime.now().subtract(const Duration(seconds: 1)), () => taps++);
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text("Passenger didn't come? Cancel ride"));
    expect(taps, 1);
  });
}
