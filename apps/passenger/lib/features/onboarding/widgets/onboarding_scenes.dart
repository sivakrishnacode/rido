import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:rido_ui/rido_ui.dart';

/// The three flat onboarding scenes (P-02a/b/c), drawn with shapes, icons and a painter.
/// They idle on a slow loop (road scrolls, vehicles bob, chips float) unless the system asks
/// for reduced motion or [animate] is false.
class OnboardingScene extends StatefulWidget {
  const OnboardingScene({
    super.key,
    required this.index,
    this.background = RidoColors.coral50,
    this.borderRadius = const BorderRadius.all(Radius.circular(RidoSpacing.xl)),
    this.animate = true,
  });

  /// 0 = bike in the city, 1 = smiling driver, 2 = bike + delivery truck.
  final int index;
  final Color background;
  final BorderRadius borderRadius;
  final bool animate;

  @override
  State<OnboardingScene> createState() => _OnboardingSceneState();
}

class _OnboardingSceneState extends State<OnboardingScene> with SingleTickerProviderStateMixin {
  late final AnimationController _loop = AnimationController(vsync: this, duration: const Duration(seconds: 3));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = !widget.animate || MediaQuery.of(context).disableAnimations;
    if (still) {
      _loop.stop();
    } else if (!_loop.isAnimating) {
      _loop.repeat();
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: ColoredBox(
        color: widget.background,
        child: LayoutBuilder(
          builder: (context, c) => AnimatedBuilder(
            animation: _loop,
            builder: (context, _) => switch (widget.index) {
              0 => _CityBikeScene(size: c.biggest, t: _loop.value),
              1 => _DriverScene(size: c.biggest, t: _loop.value),
              _ => _ParcelScene(size: c.biggest, t: _loop.value),
            },
          ),
        ),
      ),
    );
  }
}

/// Smooth -1..1 wave over one loop, [cycles] times per loop, shifted by [phase] (0..1).
double _wave(double t, {int cycles = 1, double phase = 0}) => math.sin((t * cycles + phase) * 2 * math.pi);

/// Navy road with a grey dashed centre line that scrolls with [t], across the bottom of a scene.
class _Road extends StatelessWidget {
  const _Road({required this.height, this.t = 0});
  final double height;
  final double t;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: ColoredBox(
      color: RidoColors.navy900,
      child: CustomPaint(painter: _DashPainter(t), size: Size.infinite),
    ),
  );
}

class _DashPainter extends CustomPainter {
  _DashPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = RidoColors.navy500
      ..strokeWidth = 4;
    final y = size.height * 0.52;
    // Two dash periods per loop, moving left so the vehicles look like they drive right.
    for (double x = -64 + (1 - t) * 64; x < size.width; x += 32) {
      canvas.drawLine(Offset(x, y), Offset(x + 16, y), p);
    }
  }

  @override
  bool shouldRepaint(covariant _DashPainter old) => old.t != t;
}

class _CityBikeScene extends StatelessWidget {
  const _CityBikeScene({required this.size, required this.t});
  final Size size;
  final double t;

  @override
  Widget build(BuildContext context) {
    final w = size.width;
    final h = size.height;
    final roadH = h * 0.24;
    final ground = h - roadH;
    Widget building(double left, double width, double height) => Positioned(
      left: w * left,
      bottom: roadH,
      child: Container(
        width: w * width,
        height: h * height,
        decoration: const BoxDecoration(
          color: RidoColors.coral100,
          borderRadius: BorderRadius.vertical(top: Radius.circular(RidoSpacing.m)),
        ),
      ),
    );
    final bike = h * 0.36;
    return Stack(
      children: [
        Positioned(
          right: w * 0.08,
          top: h * 0.07 + _wave(t) * h * 0.015,
          child: Container(
            width: w * 0.16,
            height: w * 0.16,
            decoration: BoxDecoration(color: RidoColors.coral500.withValues(alpha: 0.88), shape: BoxShape.circle),
          ),
        ),
        building(0.07, 0.12, 0.3),
        building(0.21, 0.17, 0.44),
        building(0.4, 0.11, 0.24),
        building(0.66, 0.15, 0.37),
        building(0.82, 0.11, 0.27),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _Road(height: roadH, t: t),
        ),
        Positioned(
          left: w * 0.5 - bike * 0.62,
          top: ground - bike * 0.78 - _wave(t, cycles: 6).abs() * h * 0.012,
          child: Icon(Symbols.two_wheeler_rounded, fill: 1, size: bike * 1.24, color: RidoColors.coral500),
        ),
      ],
    );
  }
}

class _DriverScene extends StatelessWidget {
  const _DriverScene({required this.size, required this.t});
  final Size size;
  final double t;

  @override
  Widget build(BuildContext context) {
    final type = context.type;
    final w = size.width;
    final h = size.height;
    final orb = h * 0.66;
    final face = h * 0.42;
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: orb,
          height: orb,
          decoration: const BoxDecoration(color: RidoColors.coral100, shape: BoxShape.circle),
        ),
        Transform.translate(
          offset: Offset(0, _wave(t) * h * 0.02),
          child: CustomPaint(size: Size.square(face), painter: _FacePainter()),
        ),
        Positioned(
          right: w * 0.1,
          top: h * 0.13 + _wave(t, phase: 0.25) * h * 0.02,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: RidoSpacing.l, vertical: RidoSpacing.s),
            decoration: const BoxDecoration(
              color: RidoColors.surface,
              borderRadius: RidoRadii.pillRadius,
              boxShadow: RidoShadows.soft,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Symbols.payments_rounded, color: RidoColors.success, size: 26),
                const SizedBox(width: RidoSpacing.s),
                Text(
                  '100%',
                  style: RidoTextStyles.tabular(type.h1.copyWith(color: RidoColors.success, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: w * 0.1,
          bottom: h * 0.13 + _wave(t, phase: 0.6) * h * 0.02,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: RidoSpacing.l, vertical: RidoSpacing.s),
            decoration: const BoxDecoration(color: RidoColors.coral500, borderRadius: RidoRadii.pillRadius),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Symbols.electric_rickshaw_rounded, color: RidoColors.surface, size: 20),
                const SizedBox(width: RidoSpacing.s),
                Text('Murugan · Auto', style: type.bodySemibold.copyWith(color: RidoColors.surface)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Navy face with happy "^ ^" eyes and a wide coral smile.
class _FacePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final c = size.center(Offset.zero);
    canvas.drawCircle(c, r, Paint()..color = RidoColors.navy900);
    final eye = Paint()
      ..color = RidoColors.coral100
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.1
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final dx in [-0.33, 0.33]) {
      final ex = c.dx + r * dx;
      final ey = c.dy - r * 0.22;
      canvas.drawPath(
        Path()
          ..moveTo(ex - r * 0.12, ey + r * 0.07)
          ..lineTo(ex, ey - r * 0.05)
          ..lineTo(ex + r * 0.12, ey + r * 0.07),
        eye,
      );
    }
    final smile = Path()
      ..moveTo(c.dx - r * 0.46, c.dy + r * 0.2)
      ..lineTo(c.dx + r * 0.46, c.dy + r * 0.2)
      ..arcToPoint(Offset(c.dx - r * 0.46, c.dy + r * 0.2), radius: Radius.circular(r * 0.5))
      ..close();
    canvas.drawPath(smile, Paint()..color = RidoColors.coral100);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ParcelScene extends StatelessWidget {
  const _ParcelScene({required this.size, required this.t});
  final Size size;
  final double t;

  @override
  Widget build(BuildContext context) {
    final w = size.width;
    final h = size.height;
    final roadH = h * 0.24;
    final ground = h - roadH;
    final box = h * 0.3;
    final bike = h * 0.3;
    final truck = h * 0.46;
    return Stack(
      children: [
        Positioned(
          left: w / 2 - box / 2,
          top: h * 0.12 + _wave(t) * h * 0.025,
          child: Transform.rotate(
            angle: _wave(t, phase: 0.25) * 0.06,
            child: Container(
              width: box,
              height: box,
              decoration: BoxDecoration(
                color: RidoColors.surface,
                borderRadius: BorderRadius.circular(RidoSpacing.xl),
                boxShadow: RidoShadows.soft,
              ),
              child: Icon(Symbols.package_2_rounded, size: box * 0.5, color: RidoColors.navy900),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _Road(height: roadH, t: t),
        ),
        Positioned(
          left: w * 0.04,
          top: ground - bike * 0.74 - _wave(t, cycles: 6).abs() * h * 0.012,
          child: Icon(Symbols.two_wheeler_rounded, fill: 1, size: bike * 1.2, color: RidoColors.coral500),
        ),
        Positioned(
          right: w * 0.02,
          top: ground - truck * 0.72 - _wave(t, cycles: 4, phase: 0.5).abs() * h * 0.008,
          child: Icon(Symbols.local_shipping_rounded, fill: 1, size: truck, color: RidoColors.coral500),
        ),
      ],
    );
  }
}
