import 'package:flutter_test/flutter_test.dart';
import 'package:rido_ui/rido_ui.dart';

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
}
