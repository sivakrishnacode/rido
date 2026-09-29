import 'package:flutter_test/flutter_test.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';

DriverFix _fix(int i) => DriverFix(LatLng(11 + i / 1000, 76.9), at: DateTime.fromMillisecondsSinceEpoch(1800000000000 + i * 5000));

void main() {
  test('toJson sends ts in epoch ms and leaves out unknown or invalid extras', () {
    final fix = DriverFix(const LatLng(11.01, 76.95), at: DateTime.fromMillisecondsSinceEpoch(1800000000000));
    expect(fix.toJson(), {'lat': 11.01, 'lng': 76.95, 'ts': 1800000000000, 'mock': false});
    final rich = DriverFix(const LatLng(11.01, 76.95),
        at: DateTime.fromMillisecondsSinceEpoch(1800000000000), accuracy: 4.26, speed: -1, heading: double.nan, isMocked: true);
    expect(rich.toJson(), {'lat': 11.01, 'lng': 76.95, 'ts': 1800000000000, 'acc': 4.3, 'mock': true});
  });

  test('FixBuffer keeps the newest fixes up to its capacity, oldest first', () {
    final buffer = FixBuffer(capacity: 3);
    for (var i = 0; i < 5; i++) {
      buffer.add(_fix(i));
    }
    expect(buffer.length, 3);
    final drained = buffer.drain();
    expect(drained.map((f) => f.at.millisecondsSinceEpoch), [1800000010000, 1800000015000, 1800000020000]);
    expect(buffer.isEmpty, isTrue);
  });

  test('FixBuffer.restore puts a failed upload back before newer fixes, still capped', () {
    final buffer = FixBuffer(capacity: 3)..add(_fix(0))..add(_fix(1));
    final taken = buffer.drain();
    buffer
      ..add(_fix(2))
      ..add(_fix(3))
      ..restore(taken);
    expect(buffer.drain().map((f) => f.at.millisecondsSinceEpoch), [1800000005000, 1800000010000, 1800000015000]);
  });
}
