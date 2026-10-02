import 'package:flutter_test/flutter_test.dart';
import 'package:tamiltaxi_passenger/features/ride/widgets/mode_widgets.dart';

void main() {
  test('roundUpToQuarter never goes earlier than the time it rounds', () {
    expect(roundUpToQuarter(DateTime(2026, 10, 2, 10, 15, 40)), DateTime(2026, 10, 2, 10, 30));
    expect(roundUpToQuarter(DateTime(2026, 10, 2, 10, 15)), DateTime(2026, 10, 2, 10, 15));
    expect(roundUpToQuarter(DateTime(2026, 10, 2, 10, 1)), DateTime(2026, 10, 2, 10, 15));
    expect(roundUpToQuarter(DateTime(2026, 10, 2, 23, 50)), DateTime(2026, 10, 3));
  });
}
