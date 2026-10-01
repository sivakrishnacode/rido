import 'package:flutter_test/flutter_test.dart';
import 'package:tamiltaxi_ui/tamiltaxi_ui.dart';

void main() {
  test('formatInr uses Indian grouping', () {
    expect(formatInr(38), '₹38');
    expect(formatInr(1420), '₹1,420');
    expect(formatInr(35000), '₹35,000');
    expect(formatInr(1234567), '₹12,34,567');
    expect(formatInrSigned(3), '+₹3');
  });

  test('formatCountdown', () {
    expect(formatCountdown(const Duration(seconds: 24)), '0:24');
    expect(formatCountdown(const Duration(seconds: 165)), '2:45');
  });

  test('formatWhen', () {
    final now = DateTime(2026, 10, 5, 14);
    expect(formatWhen(DateTime(2026, 10, 5, 18, 30), now: now), 'Today, 6:30 PM');
    expect(formatWhen(DateTime(2026, 10, 6, 6), now: now), 'Tomorrow, 6:00 AM');
    expect(formatWhen(DateTime(2026, 10, 9, 9, 15), now: now), 'Fri 9 Oct, 9:15 AM');
  });

  test('formatMinutes', () {
    expect(formatMinutes(45), '45 min');
    expect(formatMinutes(120), '2 h');
    expect(formatMinutes(150), '2 h 30 min');
  });
}
