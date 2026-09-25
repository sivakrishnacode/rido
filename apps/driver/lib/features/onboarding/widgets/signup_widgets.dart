import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

/// Navy sign-up app bar: back arrow, title, "Step n of 6" and a coral progress line.
class SignupAppBar extends StatelessWidget implements PreferredSizeWidget {
  const SignupAppBar({super.key, required this.title, this.step, this.total = 6, this.onBack, this.showBack = true});

  final String title;

  /// Null hides the step label and the progress line.
  final int? step;
  final int total;
  final VoidCallback? onBack;
  final bool showBack;

  @override
  Size get preferredSize => Size.fromHeight(64 + (step == null ? 0 : 4));

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Material(
        color: RidoColors.navy900,
        child: SafeArea(
          bottom: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 64,
                child: Row(
                  children: [
                    if (showBack)
                      IconButton(
                        tooltip: 'Back',
                        icon: const Icon(Symbols.arrow_back_rounded, color: Colors.white),
                        onPressed: onBack ?? () => Navigator.of(context).maybePop(),
                      )
                    else
                      const SizedBox(width: RidoSpacing.l),
                    Expanded(
                      child: Text(title,
                          style: t.h1.copyWith(color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    if (step != null)
                      Padding(
                        padding: const EdgeInsets.only(right: RidoSpacing.l, left: RidoSpacing.s),
                        child: Text('Step $step of $total',
                            style: t.bodySmallMedium.copyWith(color: RidoColors.navy300)),
                      ),
                  ],
                ),
              ),
              if (step != null)
                SizedBox(
                  height: 4,
                  child: Stack(
                    children: [
                      const Positioned.fill(child: ColoredBox(color: RidoColors.navy700)),
                      FractionallySizedBox(
                        alignment: AlignmentDirectional.centerStart,
                        widthFactor: step! / total,
                        heightFactor: 1,
                        child: const ColoredBox(color: RidoColors.coral500),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Back handler for sign-up screens reached with `go` (nothing to pop): go to [fallback].
VoidCallback backOr(BuildContext context, String fallback) => () {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(fallback);
      }
    };

/// Flat "orb" for navy headers (D-02, D-10, D-12b, S-10): navy-700 outer circle, a coloured
/// inner circle and a centred [child]. Optional accent dots.
class DriverOrb extends StatelessWidget {
  const DriverOrb({
    super.key,
    required this.color,
    required this.child,
    this.size = 160,
    this.dots = false,
    this.innerFactor = 0.7,
  });

  final Color color;
  final Widget child;
  final double size;
  final bool dots;
  final double innerFactor;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Container(
                width: size,
                height: size,
                decoration: const BoxDecoration(color: RidoColors.navy700, shape: BoxShape.circle)),
            Container(
              width: size * innerFactor,
              height: size * innerFactor,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            child,
            if (dots) ...[
              Positioned(top: size * 0.14, left: size * 0.08, child: _dot(size * 0.09, RidoColors.coral500)),
              Positioned(bottom: size * 0.12, right: size * 0.1, child: _dot(size * 0.06, RidoColors.coral100)),
            ],
          ],
        ),
      );

  Widget _dot(double d, Color c) =>
      Container(width: d, height: d, decoration: BoxDecoration(color: c, shape: BoxShape.circle));
}

/// A flat vehicle picture: the coral vehicle symbol over a soft ground shadow.
class VehicleArt extends StatelessWidget {
  const VehicleArt(this.kind, {super.key, this.size = 56, this.color = RidoColors.coral500});

  final VehicleKind kind;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: SizedBox(
          width: size * 1.5,
          height: size * 1.05,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                bottom: 0,
                child: Container(
                  width: size * 1.4,
                  height: size * 0.1,
                  decoration: BoxDecoration(
                    color: RidoColors.divider,
                    borderRadius: BorderRadius.all(Radius.elliptical(size, size * 0.1)),
                  ),
                ),
              ),
              Positioned(top: 0, child: Icon(kind.icon, size: size, color: color, fill: 1)),
            ],
          ),
        ),
      );
}

/// A circle drawn with dashes (face guides on D-09 / S-13, photo circle on D-06).
class DashedRing extends StatelessWidget {
  const DashedRing({
    super.key,
    required this.size,
    required this.child,
    this.color = RidoColors.coral500,
    this.strokeWidth = 3,
    this.dash = 10,
    this.gap = 6,
  });

  final double size;
  final Widget child;
  final Color color;
  final double strokeWidth;
  final double dash;
  final double gap;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _DashedCirclePainter(color: color, strokeWidth: strokeWidth, dash: dash, gap: gap),
          child: Center(child: child),
        ),
      );
}

class _DashedCirclePainter extends CustomPainter {
  _DashedCirclePainter({required this.color, required this.strokeWidth, required this.dash, required this.gap});

  final Color color;
  final double strokeWidth;
  final double dash;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final r = (math.min(size.width, size.height) - strokeWidth) / 2;
    final c = size.center(Offset.zero);
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final circumference = 2 * math.pi * r;
    final count = (circumference / (dash + gap)).floor();
    final sweep = (dash / circumference) * 2 * math.pi;
    final step = 2 * math.pi / count;
    final rect = Rect.fromCircle(center: c, radius: r);
    for (var i = 0; i < count; i++) {
      canvas.drawArc(rect, -math.pi / 2 + i * step, sweep, false, paint);
    }
  }

  @override
  bool shouldRepaint(_DashedCirclePainter old) =>
      old.color != color || old.strokeWidth != strokeWidth || old.dash != dash || old.gap != gap;
}

/// Pill with a leading icon (document statuses on D-07 / S-09).
class IconPill extends StatelessWidget {
  const IconPill({super.key, required this.label, required this.icon, required this.bg, required this.fg});

  final String label;
  final IconData icon;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) => Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(color: bg, borderRadius: RidoRadii.pillRadius),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: fg, fill: 1),
            const SizedBox(width: 6),
            Text(label, style: context.type.bodySmallMedium.copyWith(color: fg, fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

/// Navy header used by the document screens (D-07, S-09): app bar row, a summary line
/// and a segmented progress bar.
class DocsHeader extends StatelessWidget {
  const DocsHeader({
    super.key,
    required this.title,
    required this.summary,
    required this.segments,
    this.trailing,
    this.trailingColor = RidoColors.navy300,
    this.step,
    this.onBack,
  });

  final String title;
  final String summary;
  final String? trailing;
  final Color trailingColor;
  final int? step;
  final VoidCallback? onBack;

  /// (flex, colour) segments of the progress bar; the rest is navy-700.
  final List<(double, Color)> segments;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final filled = segments.fold<double>(0, (a, s) => a + s.$1);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Material(
        color: RidoColors.navy900,
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 64,
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Back',
                      icon: const Icon(Symbols.arrow_back_rounded, color: Colors.white),
                      onPressed: onBack ?? () => Navigator.of(context).maybePop(),
                    ),
                    Expanded(
                      child: Text(title,
                          style: t.h1.copyWith(color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    if (step != null)
                      Padding(
                        padding: const EdgeInsets.only(right: RidoSpacing.l),
                        child: Text('Step $step of 6', style: t.bodySmallMedium.copyWith(color: RidoColors.navy300)),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(RidoSpacing.l, RidoSpacing.xs, RidoSpacing.l, RidoSpacing.l),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(child: Text(summary, style: t.h2.copyWith(color: Colors.white))),
                        if (trailing != null)
                          Text(trailing!, style: t.bodySmall.copyWith(color: trailingColor)),
                      ],
                    ),
                    const SizedBox(height: RidoSpacing.m),
                    ClipRRect(
                      borderRadius: RidoRadii.pillRadius,
                      child: SizedBox(
                        height: 8,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final s in segments)
                              if (s.$1 > 0) Expanded(flex: (s.$1 * 1000).round(), child: ColoredBox(color: s.$2)),
                            if (filled < 1)
                              Expanded(
                                flex: ((1 - filled) * 1000).round(),
                                child: const ColoredBox(color: RidoColors.navy700),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom-pinned action area with safe-area padding.
class BottomActions extends StatelessWidget {
  const BottomActions({super.key, required this.children, this.color});

  final List<Widget> children;
  final Color? color;

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: color ?? Colors.transparent,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(RidoSpacing.l, RidoSpacing.m, RidoSpacing.l, RidoSpacing.m),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
          ),
        ),
      );
}

/// "DRIVER" tag next to the wordmark.
class DriverTag extends StatelessWidget {
  const DriverTag({super.key, this.large = false});
  final bool large;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(horizontal: large ? 14 : 8, vertical: large ? 4 : 2),
        decoration: const BoxDecoration(color: RidoColors.coral600, borderRadius: RidoRadii.pillRadius),
        child: Text(
          'DRIVER',
          style: (large ? context.type.bodySemibold : context.type.caption).copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            letterSpacing: large ? 3 : 1.5,
          ),
        ),
      );
}

/// Navy header for D-03a / D-03b: back arrow, big title and a subtitle line.
class AuthHeader extends StatelessWidget {
  const AuthHeader({super.key, required this.title, required this.subtitle});

  final String title;
  final Widget subtitle;

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Material(
          color: RidoColors.navy900,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(RidoSpacing.xs, RidoSpacing.s, RidoSpacing.l, RidoSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    tooltip: 'Back',
                    icon: const Icon(Symbols.arrow_back_rounded, color: Colors.white),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(height: RidoSpacing.m),
                  Padding(
                    padding: const EdgeInsets.only(left: RidoSpacing.m),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: context.type.display.copyWith(color: Colors.white)),
                        const SizedBox(height: RidoSpacing.s),
                        subtitle,
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

/// [RidoWordmark] measures its letters when it builds; on the very first screen the bundled
/// fonts may still be loading, so this rebuilds it once they are ready.
class DriverWordmark extends StatefulWidget {
  const DriverWordmark({super.key, this.size = 48, this.color = Colors.white});
  final double size;
  final Color color;

  @override
  State<DriverWordmark> createState() => _DriverWordmarkState();
}

class _DriverWordmarkState extends State<DriverWordmark> {
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    PaintingBinding.instance.systemFonts.addListener(_fontsChanged);
  }

  void _fontsChanged() {
    if (mounted) setState(() => _generation++);
  }

  @override
  void dispose() {
    PaintingBinding.instance.systemFonts.removeListener(_fontsChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      RidoWordmark(key: ValueKey(_generation), size: widget.size, color: widget.color);
}
