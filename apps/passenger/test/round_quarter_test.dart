import 'package:flutter_test/flutter_test.dart';
import 'package:tamiltaxi_passenger/features/ride/widgets/mode_widgets.dart';

void main() {
  test('roundUpToQuarter never goes earlier than the time it rounds', () {
    expect(roundUpToQuarter(DateTime(2026, 10, 2, 10, 15, 40)), DateTime(2026, 10, 2, 10, 30));
    expect(roundUpToQuarter(DateTime(2026, 10, 2, 10, 15)), DateTime(2026, 10, 2, 10, 15));
    expect(roundUpToQuarter(DateTime(2026, 10, 2, 10, 1)), DateTime(2026, 10, 2, 10, 15));
    expect(roundUpToQuarter(DateTime(2026, 10, 2, 23, 50)), DateTime(2026, 10, 3));
  });

  test("a trip booked for later starts after the server's dispatch lead plus 15 minutes", () {
    final now = DateTime(2026, 10, 2, 10, 7);
    expect(earliestLaterPickup(30, now: now), DateTime(2026, 10, 2, 11), reason: '10:07 + 45 min = 10:52 → 11:00');
    expect(earliestLaterPickup(60, now: now), DateTime(2026, 10, 2, 11, 30), reason: 'a longer lead from the server');
    expect(earliestLaterPickup(0, now: DateTime(2026, 10, 2, 10, 15)), DateTime(2026, 10, 2, 10, 30));
  });
}
