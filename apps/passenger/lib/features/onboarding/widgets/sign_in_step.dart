import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:rido_ui/rido_ui.dart';

import '../../../router/routes.dart';

/// Whether looping or decorative motion should run (off with the system "remove animations").
bool _moving(BuildContext context) => !MediaQuery.of(context).disableAnimations;

/// Shared frame for the three sign-in steps (P-03 number, P-04 verify, P-05 you).
///
/// A little scooter rides a road to the current stop, the step's badge bobs, and the heading
/// and fields rise in one after another. The routes cross-fade, so it feels like one screen.
class SignInStep extends StatelessWidget {
  const SignInStep({
    super.key,
    required this.step,
    required this.badge,
    required this.title,
    required this.subtitle,
    required this.card,
    required this.action,
    this.badgeMotion = BadgeMotion.bob,
    this.onBack,
    this.footer,
    this.overlay,
  });

  static const stops = ['Number', 'Verify', 'You'];

  /// 1-based.
  final int step;
  final IconData badge;
  final BadgeMotion badgeMotion;
  final String title;

  /// Plain text, or a widget for rich content (e.g. the phone number with "Edit").
  final Widget subtitle;
  final Widget card;

  /// Usually the step's [RidoButton] wrapped in [PopWhenReady].
  final Widget action;

  /// Null hides the back arrow (first screen reached with `go`).
  final VoidCallback? onBack;

  /// Small print above [action], e.g. [SignInTerms].
  final Widget? footer;

  /// Drawn over the whole step, e.g. a [ConfettiBurst].
  final Widget? overlay;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Scaffold(
      backgroundColor: RidoColors.surface,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                SizedBox(
                  height: 56,
                  child: Row(
                    children: [
                      const SizedBox(width: RidoSpacing.xs),
                      SizedBox(
                        width: 48,
                        child: onBack == null
                            ? null
                            : IconButton(
                                tooltip: 'Back',
                                onPressed: onBack,
                                icon: const Icon(Symbols.arrow_back_rounded, color: RidoColors.navy900),
                              ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: RidoSpacing.xl),
                  child: _RoadProgress(step: step),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(RidoSpacing.l, RidoSpacing.xl, RidoSpacing.l, RidoSpacing.l),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RiseIn(
                          order: 0,
                          child: _Badge(icon: badge, motion: badgeMotion),
                        ),
                        const SizedBox(height: RidoSpacing.l),
                        RiseIn(order: 1, child: Text(title, style: t.display)),
                        const SizedBox(height: RidoSpacing.s),
                        RiseIn(
                          order: 2,
                          child: DefaultTextStyle.merge(
                            style: t.body.copyWith(color: RidoColors.navy700),
                            child: subtitle,
                          ),
                        ),
                        const SizedBox(height: RidoSpacing.xl),
                        RiseIn(order: 3, child: card),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(RidoSpacing.l, RidoSpacing.s, RidoSpacing.l, RidoSpacing.l),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (footer != null) ...[footer!, const SizedBox(height: RidoSpacing.m)],
                      action,
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (overlay != null) Positioned.fill(child: IgnorePointer(child: overlay)),
        ],
      ),
    );
  }
}

/// A dashed road with three stops; a coral scooter pulls away from the previous stop and
/// rolls (with a small wheelie) to the current one. The road behind it turns solid coral.
class _RoadProgress extends StatefulWidget {
  const _RoadProgress({required this.step});
  final int step;

  @override
  State<_RoadProgress> createState() => _RoadProgressState();
}

class _RoadProgressState extends State<_RoadProgress> with SingleTickerProviderStateMixin {
  late final AnimationController _idle = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_moving(context)) {
      if (!_idle.isAnimating) _idle.repeat(reverse: true);
    } else {
      _idle.stop();
    }
  }

  @override
  void dispose() {
    _idle.dispose();
    super.dispose();
  }

  static const _rider = 34.0;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final to = (widget.step - 1).toDouble();
    final from = _moving(context) ? math.max(0.0, to - 1) : to;
    return Semantics(
      label: 'Step ${widget.step} of ${SignInStep.stops.length}: ${SignInStep.stops[widget.step - 1]}',
      child: ExcludeSemantics(
        child: SizedBox(
          height: 64,
          child: LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth;
              double xOf(double stop) => stop / (SignInStep.stops.length - 1) * w;
              return TweenAnimationBuilder<double>(
                tween: Tween(begin: from, end: to),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeInOutCubic,
                builder: (context, v, _) {
                  // 0 at a stop, 1 halfway between stops: drives the wheelie.
                  final travel = math.sin((v - v.floorToDouble()) * math.pi);
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: 0,
                        right: 0,
                        top: _rider - 2,
                        height: 4,
                        child: CustomPaint(painter: _RoadPainter(xOf(v))),
                      ),
                      for (var i = 0; i < SignInStep.stops.length; i++) ...[
                        Positioned(
                          left: xOf(i.toDouble()) - 7,
                          top: _rider - 7,
                          child: AnimatedScale(
                            scale: v >= i - 0.05 ? 1 : 0.8,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutBack,
                            child: Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: v >= i - 0.05 ? RidoColors.coral600 : RidoColors.surface,
                                border: Border.all(
                                  color: v >= i - 0.05 ? RidoColors.coral600 : RidoColors.navy300,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: xOf(i.toDouble()) - 40,
                          width: 80,
                          top: _rider + 12,
                          child: Text(
                            SignInStep.stops[i],
                            textAlign: TextAlign.center,
                            style: t.caption.copyWith(
                              color: i == widget.step - 1 ? RidoColors.navy900 : RidoColors.navy500,
                              fontWeight: i == widget.step - 1 ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                      AnimatedBuilder(
                        animation: _idle,
                        builder: (context, child) => Positioned(
                          left: xOf(v) - _rider / 2,
                          top: -_idle.value * 2.5 - travel * 4,
                          child: Transform.rotate(angle: -travel * 0.22, child: child),
                        ),
                        child: Container(
                          width: _rider,
                          height: _rider,
                          decoration: const BoxDecoration(
                            color: RidoColors.coral500,
                            shape: BoxShape.circle,
                            boxShadow: RidoShadows.raised,
                          ),
                          child: const Icon(Symbols.two_wheeler_rounded, fill: 1, size: 20, color: RidoColors.surface),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _RoadPainter extends CustomPainter {
  _RoadPainter(this.done);

  /// x up to which the road is travelled.
  final double done;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final dash = Paint()
      ..color = RidoColors.navy300
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (double x = done; x < size.width; x += 10) {
      canvas.drawLine(Offset(x, y), Offset(math.min(x + 5, size.width), y), dash);
    }
    canvas.drawLine(
      Offset(0, y),
      Offset(done, y),
      Paint()
        ..color = RidoColors.coral600
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _RoadPainter old) => old.done != done;
}

enum BadgeMotion {
  /// Floats up and down.
  bob,

  /// Rocks side to side like a buzzing phone.
  buzz,

  /// Waves from the wrist.
  wave,
}

/// The step's icon in a soft coral blob, with its own idle motion.
class _Badge extends StatefulWidget {
  const _Badge({required this.icon, required this.motion});
  final IconData icon;
  final BadgeMotion motion;

  @override
  State<_Badge> createState() => _BadgeState();
}

class _BadgeState extends State<_Badge> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_moving(context)) {
      if (!_c.isAnimating) _c.repeat();
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
    return SizedBox.square(
      dimension: 64,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: const BoxDecoration(
              color: RidoColors.coral50,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(28),
                topRight: Radius.circular(22),
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(30),
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _c,
            builder: (context, child) {
              final v = _c.value;
              return switch (widget.motion) {
                BadgeMotion.bob => Transform.translate(offset: Offset(0, math.sin(v * 2 * math.pi) * 3), child: child),
                // A quick buzz in the first fifth of the loop, then rest.
                BadgeMotion.buzz => Transform.rotate(
                  angle: v < 0.2 ? math.sin(v / 0.2 * 6 * math.pi) * 0.18 * (1 - v / 0.2) : 0,
                  child: child,
                ),
                // Two waves in the first half, then rest.
                BadgeMotion.wave => Transform.rotate(
                  alignment: Alignment.bottomCenter,
                  angle: v < 0.5 ? math.sin(v / 0.5 * 4 * math.pi) * 0.35 : 0,
                  child: child,
                ),
              };
            },
            child: Icon(widget.icon, fill: 1, size: 32, color: RidoColors.coral600),
          ),
        ],
      ),
    );
  }
}

/// Fades a child in while it rises 16 px; [order] staggers siblings by 70 ms.
class RiseIn extends StatefulWidget {
  const RiseIn({super.key, required this.order, required this.child});
  final int order;
  final Widget child;

  @override
  State<RiseIn> createState() => _RiseInState();
}

class _RiseInState extends State<RiseIn> with SingleTickerProviderStateMixin {
  static const _each = 420;
  static const _stagger = 70;

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: _each + widget.order * _stagger),
  );
  late final Animation<double> _a = CurvedAnimation(
    parent: _c,
    curve: Interval(widget.order * _stagger / (_each + widget.order * _stagger), 1, curve: Curves.easeOutCubic),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c.isDismissed) _moving(context) ? _c.forward() : _c.value = 1;
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _a,
    builder: (context, child) => Opacity(
      opacity: _a.value,
      child: Transform.translate(offset: Offset(0, (1 - _a.value) * 16), child: child),
    ),
    child: widget.child,
  );
}

/// Gives [child] a springy "boing" each time [ready] turns true (e.g. the form became valid).
class PopWhenReady extends StatefulWidget {
  const PopWhenReady({super.key, required this.ready, required this.child});
  final bool ready;
  final Widget child;

  @override
  State<PopWhenReady> createState() => _PopWhenReadyState();
}

class _PopWhenReadyState extends State<PopWhenReady> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));

  @override
  void didUpdateWidget(PopWhenReady old) {
    super.didUpdateWidget(old);
    if (widget.ready && !old.ready && _moving(context)) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (context, child) =>
        Transform.scale(scale: 1 + math.sin(_c.value * math.pi) * 0.06 * (1 - _c.value * 0.5), child: child),
    child: widget.child,
  );
}

/// A one-shot burst of coral, amber, green and navy confetti from [origin] (fractions of the
/// box). Increment [trigger] to fire; nothing is drawn at rest or with reduced motion.
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({super.key, required this.trigger, this.origin = const Offset(0.5, 0.45)});
  final int trigger;
  final Offset origin;

  /// How long a burst takes; callers may wait this long before navigating away.
  static const duration = Duration(milliseconds: 1100);

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: ConfettiBurst.duration);
  List<_Bit> _bits = const [];

  @override
  void didUpdateWidget(ConfettiBurst old) {
    super.didUpdateWidget(old);
    if (widget.trigger != old.trigger && _moving(context)) {
      final rnd = math.Random(widget.trigger);
      const colors = [
        RidoColors.coral500,
        RidoColors.warning,
        RidoColors.success,
        RidoColors.navy900,
        RidoColors.coral100,
      ];
      _bits = [
        for (var i = 0; i < 36; i++)
          _Bit(
            angle: -math.pi / 2 + (rnd.nextDouble() - 0.5) * math.pi * 1.3,
            speed: 260 + rnd.nextDouble() * 320,
            spin: (rnd.nextDouble() - 0.5) * 14,
            size: 5 + rnd.nextDouble() * 6,
            color: colors[i % colors.length],
            round: rnd.nextBool(),
          ),
      ];
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (context, _) => _c.isAnimating
        ? CustomPaint(painter: _ConfettiPainter(_bits, _c.value, widget.origin), size: Size.infinite)
        : const SizedBox.shrink(),
  );
}

class _Bit {
  const _Bit({
    required this.angle,
    required this.speed,
    required this.spin,
    required this.size,
    required this.color,
    required this.round,
  });
  final double angle;
  final double speed;
  final double spin;
  final double size;
  final Color color;
  final bool round;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.bits, this.t, this.origin);
  final List<_Bit> bits;
  final double t;
  final Offset origin;

  @override
  void paint(Canvas canvas, Size size) {
    final o = Offset(size.width * origin.dx, size.height * origin.dy);
    final s = t * ConfettiBurst.duration.inMilliseconds / 1000; // seconds
    final fade = t < 0.7 ? 1.0 : 1 - (t - 0.7) / 0.3;
    for (final b in bits) {
      final drag = 1 - t * 0.5;
      final p =
          o + Offset(math.cos(b.angle) * b.speed * s * drag, math.sin(b.angle) * b.speed * s * drag + 520 * s * s);
      final paint = Paint()..color = b.color.withValues(alpha: fade);
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(b.spin * s);
      if (b.round) {
        canvas.drawCircle(Offset.zero, b.size / 2, paint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: b.size, height: b.size * 0.5),
            const Radius.circular(1.5),
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => old.t != t;
}

/// "By continuing, you agree to our Terms & Privacy Policy" with tappable links.
class SignInTerms extends StatefulWidget {
  const SignInTerms({super.key});

  @override
  State<SignInTerms> createState() => _SignInTermsState();
}

class _SignInTermsState extends State<SignInTerms> {
  late final TapGestureRecognizer _terms = TapGestureRecognizer()..onTap = () => context.push(Routes.legal('terms'));
  late final TapGestureRecognizer _privacy = TapGestureRecognizer()
    ..onTap = () => context.push(Routes.legal('privacy'));

  @override
  void dispose() {
    _terms.dispose();
    _privacy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const link = TextStyle(color: RidoColors.coral600, fontWeight: FontWeight.w600);
    return Text.rich(
      TextSpan(
        style: context.type.bodySmall.copyWith(color: RidoColors.navy500),
        children: [
          const TextSpan(text: 'By continuing, you agree to our '),
          TextSpan(text: 'Terms', recognizer: _terms, style: link),
          const TextSpan(text: ' & '),
          TextSpan(text: 'Privacy Policy', recognizer: _privacy, style: link),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}
