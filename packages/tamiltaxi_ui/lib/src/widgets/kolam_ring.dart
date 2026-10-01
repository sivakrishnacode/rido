import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The rider icon's pulli-kolam border: 16 dots on a ring and a line that weaves past each one on alternating
/// sides; at the bottom two dots become lane dashes with the line running alongside them as the road's kerbs.
/// Ported from the icon build (`kolam_ring` / `trace` / `ring_marks` in the logo masters), so it matches the icon.
///
/// Sized to sit around a [TtAppName] of [nameWidth], a little wider than on the icon so the name has room on a
/// full screen. [sweep] draws it clockwise from the bottom
/// (0 = nothing, 1 = whole ring); each dot pops in as the sweep passes it.
class KolamRing extends StatelessWidget {
  const KolamRing({
    super.key,
    required this.nameWidth,
    this.sweep = 1,
    this.lineColor = Colors.white,
    this.dotColor = KolamRing.yellow,
  });

  /// The icon's pulli yellow.
  static const yellow = Color(0xFFFFC83D);

  final double nameWidth;
  final double sweep;
  final Color lineColor;
  final Color dotColor;

  /// Icon units (1000 box) per name width (the icon's name is about 640 wide; 590 leaves ~15 dp round a 122 dp name).
  static const double _unitsPerName = 590;

  /// Outer size of the ring (line and dots included) for a name of [nameWidth].
  static double sizeFor(double nameWidth) => KolamGeometry.outerRadius * 2 * nameWidth / _unitsPerName;

  @override
  Widget build(BuildContext context) {
    final side = sizeFor(nameWidth);
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size.square(side),
        painter: _KolamPainter(nameWidth / _unitsPerName, sweep, lineColor, dotColor),
      ),
    );
  }
}

/// The ring's geometry in icon units (centre 0, 0), built once.
class KolamGeometry {
  KolamGeometry._(this.line, this.dots, this.roadSlots);

  static const int n = 16;
  static const double r = 455, rho = 33, lineWidth = 17, dotRadius = 14, dashLength = 104, dashWidth = 15;
  static const double outerRadius = r + rho + lineWidth / 2 + 2;

  /// One closed line (it goes round twice: the road stretch keeps it on one side).
  final List<Offset> line;

  /// Angle of each dot (radians, 0 = east, clockwise on screen).
  final List<double> dots;

  /// The dots drawn as lane dashes (the two either side of the bottom).
  final Set<int> roadSlots;

  static final KolamGeometry rider = _build();

  static KolamGeometry _build({int steps = 24}) {
    final d = 2 * math.pi * r / n;
    final step = d / r;
    final phi = 2 * math.atan(2 * rho / d);
    final ra = rho / (1 - math.cos(phi));
    // A crossing at the very bottom; the two dots either side of it become the road.
    final rot = math.pi / 2 - (n ~/ 2) * step;
    double rem(double x, double y) => x - y * (x / y).roundToDouble();
    final road = {
      for (var k = 0; k < n; k++)
        if (rem(rot + (k + 0.5) * step - math.pi / 2, 2 * math.pi).abs() < step * 0.51) k,
    };
    // The line's side at every dot: alternate, except inside the road (consecutive road dots keep one side).
    final start = (road.reduce(math.max) + 1) % n;
    final order = [for (var i = 0; i < n; i++) (start + i) % n];
    final side = <int, int>{};
    var s = 1;
    for (var j = 0; j < order.length; j++) {
      final k = order[j];
      if (j > 0 && !(road.contains(k) && road.contains((k - 1) % n))) s = -s;
      side[k] = s;
    }
    final p1 = [for (final k in order) (k, side[k]!)];
    final p2 = [for (final k in order) (k, -side[k]!)];
    final seq = p1.last.$2 != p1.first.$2 ? p1 : [...p1, ...p2];

    // (u along the ring, v outward) points, as `trace` in the icon build.
    List<Offset> half(double uc, int sg, bool first) {
      final c = sg * (rho - ra);
      final top = sg > 0 ? math.pi / 2 : -math.pi / 2;
      final (a0, a1) = first ? (top + sg * phi, top) : (top, top - sg * phi);
      return [
        for (var i = 0; i <= steps; i++)
          Offset(uc + ra * math.cos(a0 + (a1 - a0) * i / steps), c + ra * math.sin(a0 + (a1 - a0) * i / steps)),
      ];
    }

    final uv = <Offset>[];
    for (var j = 0; j < seq.length; j++) {
      final (k, sg) = seq[j];
      final uc = (k + 0.5) * d;
      final ps = seq[(j - 1 + seq.length) % seq.length].$2;
      final ns = seq[(j + 1) % seq.length].$2;
      if (ps != sg) {
        uv.addAll(half(uc, sg, true));
      } else {
        uv.add(Offset(uc, sg * rho));
      }
      if (ns != sg) {
        uv.addAll(half(uc, sg, false));
      } else {
        for (var i = 0; i < steps; i++) {
          uv.add(Offset(uc + d * i / steps, sg * rho));
        }
      }
    }
    final line = [
      for (final p in uv) Offset((r + p.dy) * math.cos(rot + p.dx / r), (r + p.dy) * math.sin(rot + p.dx / r)),
    ];
    return KolamGeometry._(line, [for (var k = 0; k < n; k++) rot + (k + 0.5) * step], road);
  }
}

class _KolamPainter extends CustomPainter {
  _KolamPainter(this.scale, this.sweep, this.lineColor, this.dotColor);

  final double scale;
  final double sweep;
  final Color lineColor;
  final Color dotColor;

  /// The sweep starts at the bottom (the road) and runs clockwise.
  static const double _start = math.pi / 2;

  @override
  void paint(Canvas canvas, Size size) {
    if (sweep <= 0) return;
    final g = KolamGeometry.rider;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(scale);
    if (sweep < 1) {
      const big = KolamGeometry.outerRadius * 1.5;
      canvas.clipPath(Path()
        ..moveTo(0, 0)
        ..arcTo(Rect.fromCircle(center: Offset.zero, radius: big), _start, sweep * 2 * math.pi, false)
        ..close());
    }
    canvas.drawPath(
      Path()..addPolygon(g.line, true),
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = KolamGeometry.lineWidth
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true,
    );
    canvas.restore();

    // Dots (and the road's dashes) pop in just after the sweep passes them.
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(scale);
    final dot = Paint()..color = dotColor..isAntiAlias = true;
    for (var k = 0; k < g.dots.length; k++) {
      final t = g.dots[k];
      final reached = ((t - _start) % (2 * math.pi)) / (2 * math.pi);
      final pop = ((sweep - reached) / 0.12).clamp(0.0, 1.0);
      if (pop <= 0) continue;
      final grow = Curves.easeOutBack.transform(pop);
      final at = Offset(KolamGeometry.r * math.cos(t), KolamGeometry.r * math.sin(t));
      if (g.roadSlots.contains(k)) {
        final half = KolamGeometry.dashLength / 2 / KolamGeometry.r * grow;
        canvas.drawArc(
          Rect.fromCircle(center: Offset.zero, radius: KolamGeometry.r),
          t - half,
          2 * half,
          false,
          Paint()
            ..color = dotColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = KolamGeometry.dashWidth
            ..isAntiAlias = true,
        );
      } else {
        canvas.drawCircle(at, KolamGeometry.dotRadius * grow, dot);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_KolamPainter old) =>
      old.scale != scale || old.sweep != sweep || old.lineColor != lineColor || old.dotColor != dotColor;
}
