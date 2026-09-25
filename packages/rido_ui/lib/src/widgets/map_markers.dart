import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/rido_colors.dart';
import '../vehicle_ui.dart';

/// Small top-down navy vehicle (DS-06): bike, auto (amber roof), car, truck.
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
                boxShadow: [BoxShadow(color: RidoColors.shadow, blurRadius: 8, offset: Offset(0, 2))],
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

  static const _body = RidoColors.navy900;
  static const _glass = Color(0xFF94A3B8);
  static const _light = Color(0xFFFDE68A);

  /// Draws [path] with a soft shadow, a white outline and a navy fill.
  void _solid(Canvas c, Path path, double w, {Color fill = _body}) {
    c.drawShadow(path, const Color(0xFF000000), w * 0.08, false);
    c.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.07
        ..strokeJoin = StrokeJoin.round,
    );
    c.drawPath(path, Paint()..color = fill);
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
        // Body with a slightly narrower nose, windscreen, roof, rear glass, mirrors, lights.
        final body = Path()..addRRect(_rr(c, w * 0.46, w * 0.9, w * 0.14));
        _solid(canvas, body, w);
        canvas.drawRRect(_rr(c.translate(-w * 0.26, -w * 0.12), w * 0.08, w * 0.06, w * 0.02), fill..color = _body);
        canvas.drawRRect(_rr(c.translate(w * 0.26, -w * 0.12), w * 0.08, w * 0.06, w * 0.02), fill..color = _body);
        final windscreen = Path()
          ..moveTo(c.dx - w * 0.17, c.dy - w * 0.1)
          ..lineTo(c.dx + w * 0.17, c.dy - w * 0.1)
          ..lineTo(c.dx + w * 0.13, c.dy - w * 0.24)
          ..lineTo(c.dx - w * 0.13, c.dy - w * 0.24)
          ..close();
        canvas.drawPath(windscreen, fill..color = _glass);
        canvas.drawRRect(
          _rr(c.translate(0, w * 0.04), w * 0.32, w * 0.24, w * 0.05),
          fill..color = const Color(0xFF334155),
        );
        canvas.drawRRect(_rr(c.translate(0, w * 0.26), w * 0.28, w * 0.08, w * 0.03), fill..color = _glass);
        canvas.drawCircle(c.translate(-w * 0.14, -w * 0.41), w * 0.035, fill..color = _light);
        canvas.drawCircle(c.translate(w * 0.14, -w * 0.41), w * 0.035, fill..color = _light);
      case MapVehicleType.auto:
        // Auto-rickshaw: narrow front with one wheel, wider rear cabin under an amber canopy.
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
        _solid(canvas, body, w);
        canvas.drawRRect(_rr(c.translate(0, w * 0.08), w * 0.42, w * 0.52, w * 0.1), fill..color = RidoColors.warning);
        canvas.drawRRect(
          _rr(c.translate(0, w * 0.08), w * 0.3, w * 0.04, w * 0.02),
          fill..color = const Color(0xFFB45309),
        );
        canvas.drawRRect(_rr(c.translate(0, -w * 0.28), w * 0.22, w * 0.06, w * 0.03), fill..color = _glass);
        canvas.drawCircle(c.translate(0, -w * 0.4), w * 0.035, fill..color = _light);
      case MapVehicleType.bike:
        // Scooter from above: tyres, body, seat, handlebar with grips, rider's coral helmet.
        canvas.drawRRect(
          _rr(c.translate(0, -w * 0.32), w * 0.09, w * 0.2, w * 0.045),
          fill..color = const Color(0xFF0F172A),
        );
        canvas.drawRRect(
          _rr(c.translate(0, w * 0.34), w * 0.1, w * 0.2, w * 0.05),
          fill..color = const Color(0xFF0F172A),
        );
        final body = Path()..addRRect(_rr(c.translate(0, w * 0.04), w * 0.2, w * 0.56, w * 0.1));
        _solid(canvas, body, w);
        final bar = Path()..addRRect(_rr(c.translate(0, -w * 0.2), w * 0.52, w * 0.07, w * 0.035));
        _solid(canvas, bar, w);
        canvas.drawRRect(
          _rr(c.translate(-w * 0.24, -w * 0.2), w * 0.07, w * 0.08, w * 0.03),
          fill..color = const Color(0xFF0F172A),
        );
        canvas.drawRRect(
          _rr(c.translate(w * 0.24, -w * 0.2), w * 0.07, w * 0.08, w * 0.03),
          fill..color = const Color(0xFF0F172A),
        );
        final helmet = Path()..addOval(Rect.fromCircle(center: c.translate(0, w * 0.02), radius: w * 0.14));
        _solid(canvas, helmet, w, fill: RidoColors.coral500);
        canvas.drawRRect(
          _rr(c.translate(0, -w * 0.06), w * 0.16, w * 0.05, w * 0.025),
          fill..color = const Color(0xFF1E293B),
        );
      case MapVehicleType.truck:
        // Cab up front, cargo box behind.
        final cab = Path()..addRRect(_rr(c.translate(0, -w * 0.3), w * 0.44, w * 0.26, w * 0.08));
        _solid(canvas, cab, w);
        canvas.drawRRect(_rr(c.translate(0, -w * 0.36), w * 0.32, w * 0.07, w * 0.02), fill..color = _glass);
        final box = Path()..addRRect(_rr(c.translate(0, w * 0.14), w * 0.52, w * 0.58, w * 0.05));
        _solid(canvas, box, w, fill: const Color(0xFF334155));
        for (final dy in [-0.02, 0.14, 0.3]) {
          canvas.drawRect(
            Rect.fromCenter(center: c.translate(0, w * dy), width: w * 0.42, height: w * 0.02),
            fill..color = const Color(0xFF475569),
          );
        }
    }
  }

  @override
  bool shouldRepaint(covariant _VehiclePainter old) => old.type != type;
}

/// Expanding coral pulse ring (P-12 finding driver, D-14 online).
class PulseRing extends StatefulWidget {
  const PulseRing({super.key, this.color = RidoColors.coral500, this.size = 180, this.animate = true});

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
