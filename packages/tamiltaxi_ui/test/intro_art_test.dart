import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:tamiltaxi_ui/src/widgets/tt_logo_paths.dart';
import 'package:tamiltaxi_ui/tamiltaxi_ui.dart';

Offset _centre(List<Offset> pts) => pts.reduce((a, b) => a + b) / pts.length.toDouble();

void main() {
  group('AppNameRoad (the x of the app name)', () {
    final name = TtLogoPaths.appName();
    final dash = _centre(AppNameRoad.dash);

    test('matches the generated logo: two lane dashes cut out of the over-road band', () {
      expect(name.contains(dash), isFalse, reason: 'first dash is a hole');
      expect(name.contains(dash + AppNameRoad.period), isFalse, reason: 'second dash is a hole');
      expect(name.contains(dash + AppNameRoad.period * 0.5), isTrue, reason: 'road between the dashes');
      expect(name.contains(_centre(AppNameRoad.band)), isTrue);
    });

    test('moving the lanes half a period swaps road and dash; whole periods give the logo back', () {
      final half = AppNameRoad.nameAt(0.5);
      expect(half.contains(dash), isTrue);
      expect(half.contains(dash + AppNameRoad.period * 0.5), isFalse);
      final two = AppNameRoad.nameAt(2);
      expect(two.contains(dash), isFalse);
      expect(two.contains(dash + AppNameRoad.period * 0.5), isTrue);
    });

    test('moved dashes never leave the band: the rest of the name is untouched', () {
      final moved = AppNameRoad.nameAt(0.37);
      // Points in the T, the a, the i and the Tamil line.
      for (final p in const [Offset(0.2, 0.62), Offset(0.45, 0.83), Offset(0.87, 0.75), Offset(0.15, 0.35)]) {
        expect(moved.contains(p), name.contains(p), reason: '$p');
      }
    });
  });

  group('KolamGeometry (the rider icon ring)', () {
    final g = KolamGeometry.rider;

    test('16 pulli, the two either side of the bottom are the road', () {
      expect(g.dots, hasLength(16));
      expect(g.roadSlots, hasLength(2));
      for (final k in g.roadSlots) {
        final fromBottom = (g.dots[k] - math.pi / 2 + math.pi) % (2 * math.pi) - math.pi;
        expect(fromBottom.abs(), lessThan(2 * math.pi / 16));
      }
    });

    test('the line weaves within the rim, round the whole ring', () {
      for (final p in g.line) {
        expect(p.distance, inInclusiveRange(KolamGeometry.r - KolamGeometry.rho - 1, KolamGeometry.r + KolamGeometry.rho + 1));
      }
      final angles = {for (final p in g.line) ((math.atan2(p.dy, p.dx) + 2 * math.pi) % (2 * math.pi) * 8 / math.pi).floor()};
      expect(angles, hasLength(16), reason: 'every 22.5° sector is crossed');
    });
  });
}
