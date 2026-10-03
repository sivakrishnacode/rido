import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tt_colors.dart';
import '../theme/tt_tokens.dart';

/// Circular countdown (D-15 / D-20). Runs by itself for [duration] and calls [onFinished].
/// Shows a navy "9s" badge at the top and [child] in the centre.
class CountdownRing extends StatefulWidget {
  const CountdownRing({
    super.key,
    required this.duration,
    required this.child,
    this.onFinished,
    this.size = 184,
    this.strokeWidth = 10,
    this.color = Colors.white,
    this.trackColor = const Color(0x33000000),
    this.running = true,
    this.showBadge = true,
  });

  /// False hides the "9s" badge (small rings, e.g. a list of requests).
  final bool showBadge;

  final Duration duration;
  final Widget child;
  final VoidCallback? onFinished;
  final double size;
  final double strokeWidth;
  final Color color;
  final Color trackColor;

  /// False freezes the ring (gallery showcase).
  final bool running;

  @override
  State<CountdownRing> createState() => _CountdownRingState();
}

class _CountdownRingState extends State<CountdownRing> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.duration)
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onFinished?.call();
    });

  @override
  void initState() {
    super.initState();
    if (widget.running) {
      _c.forward();
    } else {
      _c.value = 0.4;
    }
  }

  @override
  void didUpdateWidget(CountdownRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duration != oldWidget.duration) {
      _c.duration = widget.duration;
      _c.value = 0;
    }
    if (widget.running) {
      _c.forward();
    } else {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final remaining = (widget.duration.inMilliseconds * (1 - _c.value) / 1000).ceil();
        return Semantics(
          label: '$remaining seconds left',
          child: SizedBox(
            width: widget.size,
            height: widget.size + (widget.showBadge ? 16 : 0),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  top: widget.showBadge ? 16 : 0,
                  child: CustomPaint(
                    size: Size.square(widget.size),
                    painter: _RingPainter(1 - _c.value, widget.color, widget.trackColor, widget.strokeWidth),
                  ),
                ),
                Positioned(
                    top: widget.showBadge ? 16 : 0, width: widget.size, height: widget.size, child: Center(child: child)),
                if (widget.showBadge)
                  Positioned(
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: const BoxDecoration(color: TtColors.navy900, borderRadius: TtRadii.pillRadius),
                    child: Text(
                      '${remaining}s',
                      style: TtTextStyles.tabular(context.type.bodySemibold.copyWith(color: Colors.white)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.fraction, this.color, this.track, this.stroke);
  final double fraction;
  final Color color;
  final Color track;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final r = rect.deflate(stroke / 2);
    canvas.drawArc(r, 0, math.pi * 2, false, Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke);
    canvas.drawArc(
      r,
      -math.pi / 2,
      math.pi * 2 * fraction,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.fraction != fraction;
}
