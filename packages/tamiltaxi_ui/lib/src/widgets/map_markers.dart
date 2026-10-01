import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tt_colors.dart';
import '../vehicle_ui.dart';

/// Small top-down vehicle (DS-06), coloured like the vehicle pictures (`VehicleArt`): a white taxi with amber side
/// stripes, a yellow auto under a black canopy, a white-and-yellow bike with a yellow helmet, a white truck.
/// Rotates to [heading] (degrees, 0 = north).
class VehicleMarker extends StatelessWidget {
  const VehicleMarker({super.key, required this.type, this.heading = 0, this.large = false});

  final MapVehicleType type;
  final double heading;

  /// Adds a white halo, for the assigned driver / driver's own vehicle.
  final bool large;

  @override
  Widget build(BuildContext context) {
    final glyph = Transform.rotate(
      angle: heading * math.pi / 180,
      child: CustomPaint(size: Size.square(large ? 40 : 36), painter: _VehiclePainter(type)),
    );
    return Semantics(
      label: '${type.name} on map',
      child: large
          ? Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: TtColors.shadow, blurRadius: 8, offset: Offset(0, 2))],
              ),
              alignment: Alignment.center,
              child: glyph,
            )
          : glyph,
    );
  }
}

class _VehiclePainter extends CustomPainter {
  _VehiclePainter(this.type);
  final MapVehicleType type;

  static const _white = Color(0xFFFFFFFF);
  static const _edge = Color(0xFF94A3B8);
  static const _glass = Color(0xFF1F2937);
  static const _tyre = Color(0xFF111827);
  static const _amber = Color(0xFFF5B700);
  static const _yellow = Color(0xFFFFC400);
  static const _canopy = Color(0xFF23272E);
  static const _head = Color(0xFFFFF3C4);
  static const _tail = Color(0xFFE53935);

  /// [path] with a soft shadow, a thin outline (so white bodies show on the light map) and [fill].
  void _solid(Canvas c, Path path, double w, Color fill, {Color edge = _edge}) {
    c.drawShadow(path, const Color(0xFF000000), w * 0.09, false);
    c.drawPath(path, Paint()..color = fill);
    c.drawPath(
      path,
      Paint()
        ..color = edge
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.03
        ..strokeJoin = StrokeJoin.round,
    );
  }

  RRect _rr(Offset c, double w, double h, double r) =>
      RRect.fromRectAndRadius(Rect.fromCenter(center: c, width: w, height: h), Radius.circular(r));

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final c = size.center(Offset.zero);
    final fill = Paint();

    switch (type) {
      case MapVehicleType.car:
        // White taxi from above: mirrors, bonnet, windscreen, roof, rear glass, amber side stripes, lights.
        canvas.drawRRect(_rr(c.translate(-w * 0.255, -w * 0.12), w * 0.08, w * 0.06, w * 0.02), fill..color = _glass);
        canvas.drawRRect(_rr(c.translate(w * 0.255, -w * 0.12), w * 0.08, w * 0.06, w * 0.02), fill..color = _glass);
        _solid(canvas, Path()..addRRect(_rr(c, w * 0.46, w * 0.9, w * 0.15)), w, _white);
        final windscreen = Path()
          ..moveTo(c.dx - w * 0.18, c.dy - w * 0.1)
          ..lineTo(c.dx + w * 0.18, c.dy - w * 0.1)
          ..lineTo(c.dx + w * 0.14, c.dy - w * 0.25)
          ..lineTo(c.dx - w * 0.14, c.dy - w * 0.25)
          ..close();
        canvas.drawPath(windscreen, fill..color = _glass);
        canvas.drawRRect(_rr(c.translate(0, w * 0.27), w * 0.3, w * 0.09, w * 0.03), fill..color = _glass);
        canvas.drawRRect(_rr(c.translate(0, w * 0.08), w * 0.3, w * 0.3, w * 0.06), fill..color = const Color(0xFFF1F5F9));
        for (final dx in [-0.205, 0.205]) {
          canvas.drawRRect(_rr(c.translate(w * dx, w * 0.06), w * 0.035, w * 0.36, w * 0.015), fill..color = _amber);
        }
        canvas.drawRRect(_rr(c.translate(-w * 0.14, -w * 0.415), w * 0.1, w * 0.035, w * 0.015), fill..color = _head);
        canvas.drawRRect(_rr(c.translate(w * 0.14, -w * 0.415), w * 0.1, w * 0.035, w * 0.015), fill..color = _head);
        canvas.drawRRect(_rr(c.translate(-w * 0.15, w * 0.425), w * 0.09, w * 0.03, w * 0.015), fill..color = _tail);
        canvas.drawRRect(_rr(c.translate(w * 0.15, w * 0.425), w * 0.09, w * 0.03, w * 0.015), fill..color = _tail);
      case MapVehicleType.auto:
        // Auto-rickshaw: a yellow nose with one wheel in front, the black canopy over the wider rear.
        final body = Path()
          ..moveTo(c.dx, c.dy - w * 0.44)
          ..quadraticBezierTo(c.dx + w * 0.16, c.dy - w * 0.42, c.dx + w * 0.2, c.dy - w * 0.2)
          ..lineTo(c.dx + w * 0.25, c.dy + w * 0.3)
          ..quadraticBezierTo(c.dx + w * 0.25, c.dy + w * 0.42, c.dx + w * 0.12, c.dy + w * 0.42)
          ..lineTo(c.dx - w * 0.12, c.dy + w * 0.42)
          ..quadraticBezierTo(c.dx - w * 0.25, c.dy + w * 0.42, c.dx - w * 0.25, c.dy + w * 0.3)
          ..lineTo(c.dx - w * 0.2, c.dy - w * 0.2)
          ..quadraticBezierTo(c.dx - w * 0.16, c.dy - w * 0.42, c.dx, c.dy - w * 0.44)
          ..close();
        _solid(canvas, body, w, _yellow, edge: const Color(0xFFB45309));
        canvas.drawRRect(_rr(c.translate(0, -w * 0.29), w * 0.24, w * 0.07, w * 0.03), fill..color = _glass);
        _solid(canvas, Path()..addRRect(_rr(c.translate(0, w * 0.09), w * 0.46, w * 0.56, w * 0.12)), w, _canopy,
            edge: const Color(0xFF0B0D10));
        canvas.drawRRect(
          _rr(c.translate(0, w * 0.09), w * 0.34, w * 0.03, w * 0.015),
          fill..color = const Color(0xFF3A3F47),
        );
        canvas.drawCircle(c.translate(0, -w * 0.41), w * 0.035, fill..color = _head);
      case MapVehicleType.bike:
        // Bike from above: tyres, white body with a yellow tank, black handlebar and grips, the rider's yellow helmet.
        canvas.drawRRect(_rr(c.translate(0, -w * 0.32), w * 0.09, w * 0.2, w * 0.045), fill..color = _tyre);
        canvas.drawRRect(_rr(c.translate(0, w * 0.34), w * 0.1, w * 0.2, w * 0.05), fill..color = _tyre);
        _solid(canvas, Path()..addRRect(_rr(c.translate(0, w * 0.04), w * 0.2, w * 0.56, w * 0.1)), w, _white);
        canvas.drawRRect(_rr(c.translate(0, -w * 0.1), w * 0.14, w * 0.14, w * 0.06), fill..color = _amber);
        _solid(canvas, Path()..addRRect(_rr(c.translate(0, -w * 0.2), w * 0.52, w * 0.07, w * 0.035)), w, _tyre,
            edge: _tyre);
        canvas.drawRRect(_rr(c.translate(-w * 0.24, -w * 0.2), w * 0.07, w * 0.08, w * 0.03), fill..color = _tyre);
        canvas.drawRRect(_rr(c.translate(w * 0.24, -w * 0.2), w * 0.07, w * 0.08, w * 0.03), fill..color = _tyre);
        _solid(canvas, Path()..addOval(Rect.fromCircle(center: c.translate(0, w * 0.06), radius: w * 0.14)), w, _yellow,
            edge: const Color(0xFFB45309));
        canvas.drawRRect(_rr(c.translate(0, -w * 0.02), w * 0.16, w * 0.05, w * 0.025), fill..color = _glass);
        canvas.drawCircle(c.translate(0, -w * 0.42), w * 0.03, fill..color = _head);
      case MapVehicleType.truck:
        // White cab up front, a light grey cargo box behind with an amber stripe.
        _solid(canvas, Path()..addRRect(_rr(c.translate(0, -w * 0.3), w * 0.44, w * 0.26, w * 0.08)), w, _white);
        canvas.drawRRect(_rr(c.translate(0, -w * 0.36), w * 0.32, w * 0.07, w * 0.02), fill..color = _glass);
        _solid(canvas, Path()..addRRect(_rr(c.translate(0, w * 0.14), w * 0.52, w * 0.58, w * 0.05)), w,
            const Color(0xFFE2E8F0));
        canvas.drawRect(
          Rect.fromCenter(center: c.translate(0, w * 0.14), width: w * 0.42, height: w * 0.05),
          fill..color = _amber,
        );
        canvas.drawRRect(_rr(c.translate(-w * 0.16, -w * 0.43), w * 0.08, w * 0.03, w * 0.015), fill..color = _head);
        canvas.drawRRect(_rr(c.translate(w * 0.16, -w * 0.43), w * 0.08, w * 0.03, w * 0.015), fill..color = _head);
    }
  }

  @override
  bool shouldRepaint(covariant _VehiclePainter old) => old.type != type;
}

/// Expanding round radar pulse while searching (P-12 finding driver, coral; D-14 online, green). A search
/// animation, not an area, so it stays round while map areas are hexes.
class PulseRing extends StatefulWidget {
  const PulseRing({super.key, this.color = TtColors.coral500, this.size = 180, this.animate = true});

  final Color color;
  final double size;
  final bool animate;

  @override
  State<PulseRing> createState() => _PulseRingState();
}

class _PulseRingState extends State<PulseRing> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      _c.repeat();
    } else {
      _c.value = 0.5;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedBuilder(
      animation: _c,
      builder: (context, _) =>
          CustomPaint(size: Size.square(widget.size), painter: _PulsePainter(_c.value, widget.color)),
    ),
  );
}

class _PulsePainter extends CustomPainter {
  _PulsePainter(this.t, this.color);
  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final maxR = size.width / 2;
    for (final offset in [0.0, 0.5]) {
      final p = (t + offset) % 1.0;
      canvas.drawCircle(c, maxR * (0.2 + 0.8 * p), Paint()..color = color.withValues(alpha: 0.28 * (1 - p)));
    }
    canvas.drawCircle(
      c,
      maxR * 0.2,
      Paint()
        ..color = color.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _PulsePainter old) => old.t != t;
}

/// A pointy-top hexagon (a corner points up) around [centre] with corner distance [r]: the H3 cell shape, used
/// on maps in place of circles ("location lost", the design board's area swatch).
Path hexagonPath(Offset centre, double r) {
  final path = Path();
  for (var i = 0; i < 6; i++) {
    final a = (-90 + 60 * i) * math.pi / 180;
    final p = centre + Offset(r * math.cos(a), r * math.sin(a));
    i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
  }
  return path..close();
}

/// [hexagonPath] as a dashed outline: [dashes] dashes over the six sides.
void drawDashedHexagon(Canvas canvas, Offset centre, double r, Paint paint, {int dashes = 30, double on = 0.55}) {
  for (final metric in hexagonPath(centre, r).computeMetrics()) {
    final step = metric.length / dashes;
    for (var i = 0; i < dashes; i++) {
      canvas.drawPath(metric.extractPath(i * step, i * step + step * on), paint);
    }
  }
}
