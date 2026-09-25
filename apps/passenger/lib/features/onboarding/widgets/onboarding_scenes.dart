import 'package:flutter/material.dart';
import 'package:rido_ui/rido_ui.dart';

/// The three flat onboarding scenes (P-02a/b/c), drawn with shapes, icons and a painter.
class OnboardingScene extends StatelessWidget {
  const OnboardingScene({super.key, required this.index});

  /// 0 = bike in the city, 1 = smiling driver, 2 = bike + delivery truck.
  final int index;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(RidoSpacing.xl),
      child: ColoredBox(
        color: RidoColors.coral50,
        child: LayoutBuilder(
          builder: (context, c) => switch (index) {
            0 => _CityBikeScene(size: c.biggest),
            1 => _DriverScene(size: c.biggest),
            _ => _ParcelScene(size: c.biggest),
          },
        ),
      ),
    );
  }
}

/// Navy road with a grey dashed centre line, across the bottom of a scene.
class _Road extends StatelessWidget {
  const _Road({required this.height});
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: ColoredBox(
      color: RidoColors.navy900,
      child: CustomPaint(painter: _DashPainter(), size: Size.infinite),
    ),
  );
}

class _DashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = RidoColors.navy500
      ..strokeWidth = 4;
    final y = size.height * 0.52;
    for (double x = 0; x < size.width; x += 32) {
      canvas.drawLine(Offset(x, y), Offset(x + 16, y), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CityBikeScene extends StatelessWidget {
  const _CityBikeScene({required this.size});
  final Size size;

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
          top: h * 0.07,
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
        Positioned(left: 0, right: 0, bottom: 0, child: _Road(height: roadH)),
        Positioned(
          left: w * 0.5 - bike * 0.62,
          top: ground - bike * 0.78,
          child: Icon(Symbols.two_wheeler_rounded, fill: 1, size: bike * 1.24, color: RidoColors.coral500),
        ),
      ],
    );
  }
}

class _DriverScene extends StatelessWidget {
  const _DriverScene({required this.size});
  final Size size;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
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
        CustomPaint(size: Size.square(face), painter: _FacePainter()),
        Positioned(
          right: w * 0.1,
          top: h * 0.13,
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
                  style: RidoTextStyles.tabular(t.h1.copyWith(color: RidoColors.success, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: w * 0.1,
          bottom: h * 0.13,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: RidoSpacing.l, vertical: RidoSpacing.s),
            decoration: const BoxDecoration(color: RidoColors.coral500, borderRadius: RidoRadii.pillRadius),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Symbols.electric_rickshaw_rounded, color: RidoColors.surface, size: 20),
                const SizedBox(width: RidoSpacing.s),
                Text('Murugan · Auto', style: t.bodySemibold.copyWith(color: RidoColors.surface)),
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
  const _ParcelScene({required this.size});
  final Size size;

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
          top: h * 0.12,
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
        Positioned(left: 0, right: 0, bottom: 0, child: _Road(height: roadH)),
        Positioned(
          left: w * 0.04,
          top: ground - bike * 0.74,
          child: Icon(Symbols.two_wheeler_rounded, fill: 1, size: bike * 1.2, color: RidoColors.coral500),
        ),
        Positioned(
          right: w * 0.02,
          top: ground - truck * 0.72,
          child: Icon(Symbols.local_shipping_rounded, fill: 1, size: truck, color: RidoColors.coral500),
        ),
      ],
    );
  }
}
