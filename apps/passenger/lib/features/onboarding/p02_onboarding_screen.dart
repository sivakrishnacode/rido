import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

import '../../router/routes.dart';
import 'widgets/onboarding_scenes.dart';

class _Slide {
  const _Slide(this.title, this.body, this.tint, {this.caption});
  final String title;
  final String body;

  /// Colour of the scene panel; the panel blends between tints while swiping.
  final Color tint;
  final String? caption;
}

const _slides = [
  _Slide(
    'Lower fares, every ride',
    'Bike, auto or cab across Coimbatore — with no commission added to your fare.',
    RidoColors.coral50,
  ),
  _Slide(
    'Your driver keeps 100%',
    'Drivers pay Rido a small monthly plan. Every rupee you pay goes to them.',
    Color(0xFFFFF4D9),
    caption: 'Rido takes 0% commission.',
  ),
  _Slide(
    'Rides and parcels in one app',
    'Book a ride to Brookefields or send a tiffin to RS Puram — same app, same fair prices.',
    Color(0xFFE5F6EC),
  ),
];

/// P-02 Onboarding: three slides (P-02a/b/c). A tinted scene panel that blends colour as you
/// swipe, parallax scenes, text that rises in, and a ring "next" button that stretches into
/// "Get started" on the last slide.
class P02OnboardingScreen extends ConsumerStatefulWidget {
  const P02OnboardingScreen({super.key, this.initialPage = 0, this.showcase = false});

  final int initialPage;

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  @override
  ConsumerState<P02OnboardingScreen> createState() => _P02OnboardingScreenState();
}

class _P02OnboardingScreenState extends ConsumerState<P02OnboardingScreen> {
  late final PageController _pages = PageController(initialPage: widget.initialPage.clamp(0, 2));
  late int _page = widget.initialPage.clamp(0, 2);

  bool get _last => _page == _slides.length - 1;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _finish() {
    ref.read(authRepositoryProvider).markOnboardingSeen();
    context.go(Routes.login);
  }

  void _nextPage() => _pages.nextPage(duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic);

  /// Fractional page while swiping; the initial page before the controller is attached.
  double get _position => _pages.hasClients && _pages.position.haveDimensions ? _pages.page ?? 0 : _page.toDouble();

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: RidoColors.surface,
      body: LayoutBuilder(
        builder: (context, c) {
          final panelH = (c.maxHeight * 0.56).clamp(300.0, 520.0);
          final sceneTop = topInset + 56;
          final sceneH = panelH - sceneTop - RidoSpacing.xl;
          return Stack(
            children: [
              // Tinted panel behind the scenes, blending between slide colours.
              AnimatedBuilder(
                animation: _pages,
                builder: (context, _) => Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: panelH,
                  child: _Panel(position: _position),
                ),
              ),
              PageView.builder(
                controller: _pages,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) => AnimatedBuilder(
                  animation: _pages,
                  builder: (context, _) => _SlideView(
                    index: i,
                    slide: _slides[i],
                    delta: _position - i,
                    width: c.maxWidth,
                    sceneTop: sceneTop,
                    sceneH: sceneH,
                    textTop: panelH + RidoSpacing.xl,
                  ),
                ),
              ),
              Positioned(
                top: topInset,
                right: RidoSpacing.s,
                height: 56,
                child: AnimatedOpacity(
                  opacity: _last ? 0 : 1,
                  duration: const Duration(milliseconds: 200),
                  child: IgnorePointer(
                    ignoring: _last,
                    child: TextButton(
                      onPressed: _finish,
                      style: TextButton.styleFrom(
                        foregroundColor: RidoColors.navy900,
                        backgroundColor: RidoColors.surface.withValues(alpha: 0.7),
                        minimumSize: const Size(64, 40),
                        shape: const StadiumBorder(),
                      ),
                      child: Text('Skip', style: context.type.bodySemibold.copyWith(color: RidoColors.navy900)),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: RidoSpacing.l,
                right: RidoSpacing.l,
                bottom: MediaQuery.paddingOf(context).bottom + RidoSpacing.xl,
                child: _Controls(page: _page, onNext: _nextPage, onFinish: _finish),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The rounded scene panel: its colour follows the swipe, with a few twinkling sparkles.
class _Panel extends StatefulWidget {
  const _Panel({required this.position});
  final double position;

  @override
  State<_Panel> createState() => _PanelState();
}

class _PanelState extends State<_Panel> with SingleTickerProviderStateMixin {
  late final AnimationController _twinkle = AnimationController(vsync: this, duration: const Duration(seconds: 4));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _twinkle.stop();
    } else if (!_twinkle.isAnimating) {
      _twinkle.repeat();
    }
  }

  @override
  void dispose() {
    _twinkle.dispose();
    super.dispose();
  }

  Color get _tint {
    final p = widget.position.clamp(0.0, _slides.length - 1.0);
    final i = p.floor().clamp(0, _slides.length - 2);
    return Color.lerp(_slides[i].tint, _slides[i + 1].tint, p - i)!;
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _tint,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(40)),
      ),
      child: LayoutBuilder(
        builder: (context, c) => AnimatedBuilder(
          animation: _twinkle,
          builder: (context, _) => Stack(
            children: [
              for (final (i, s) in const [
                (0.08, 0.22, 18.0),
                (0.86, 0.34, 14.0),
                (0.14, 0.62, 12.0),
                (0.72, 0.14, 16.0),
              ].indexed)
                Positioned(
                  left: c.maxWidth * s.$1,
                  top: c.maxHeight * s.$2,
                  child: Opacity(
                    opacity: 0.35 + 0.45 * (0.5 + 0.5 * math.sin((_twinkle.value + i * 0.27) * 2 * math.pi)),
                    child: Transform.rotate(
                      angle: _twinkle.value * 2 * math.pi * (i.isEven ? 0.25 : -0.25),
                      child: Icon(Symbols.auto_awesome_rounded, fill: 1, size: s.$3, color: RidoColors.surface),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  const _SlideView({
    required this.index,
    required this.slide,
    required this.delta,
    required this.width,
    required this.sceneTop,
    required this.sceneH,
    required this.textTop,
  });

  final int index;
  final _Slide slide;

  /// Current page minus this page: 0 when centred, ±1 one page away.
  final double delta;
  final double width;
  final double sceneTop;
  final double sceneH;
  final double textTop;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final away = delta.abs().clamp(0.0, 1.0);
    // Text fades out quickly and sinks a little, so only the centred slide reads.
    final textOpacity = (1 - away * 1.8).clamp(0.0, 1.0);
    return Stack(
      children: [
        Positioned(
          top: sceneTop,
          left: RidoSpacing.l,
          right: RidoSpacing.l,
          height: sceneH,
          // Parallax: the scene drifts at 40% of the page speed and shrinks slightly off-centre.
          child: Transform.translate(
            offset: Offset(delta * width * 0.4, 0),
            child: Transform.scale(
              scale: 1 - away * 0.12,
              child: OnboardingScene(index: index, background: Colors.transparent),
            ),
          ),
        ),
        Positioned(
          top: textTop,
          left: RidoSpacing.l,
          right: RidoSpacing.l,
          bottom: 112,
          child: Opacity(
            opacity: textOpacity,
            child: Transform.translate(
              offset: Offset(0, away * 28),
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: RidoSpacing.s),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(slide.title, style: t.display),
                    const SizedBox(height: RidoSpacing.m),
                    Text(slide.body, style: t.body.copyWith(color: RidoColors.navy700)),
                    if (slide.caption != null) ...[
                      const SizedBox(height: RidoSpacing.m),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: RidoSpacing.m, vertical: 6),
                        decoration: const BoxDecoration(color: RidoColors.coral50, borderRadius: RidoRadii.pillRadius),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Symbols.verified_rounded, fill: 1, size: 18, color: RidoColors.coral600),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                slide.caption!,
                                style: t.bodySmallMedium.copyWith(
                                  color: RidoColors.coral600,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Dots on the left, a round "next" button with a progress ring on the right. On the last
/// slide the dots fade and the button stretches into a full-width "Get started".
class _Controls extends StatelessWidget {
  const _Controls({required this.page, required this.onNext, required this.onFinish});
  final int page;
  final VoidCallback onNext;
  final VoidCallback onFinish;

  static const _size = 64.0;

  @override
  Widget build(BuildContext context) {
    final last = page == _slides.length - 1;
    const morph = Duration(milliseconds: 420);
    return SizedBox(
      height: _size,
      child: LayoutBuilder(
        builder: (context, c) => Stack(
          alignment: Alignment.centerLeft,
          children: [
            AnimatedOpacity(
              opacity: last ? 0 : 1,
              duration: morph,
              child: _Dots(page: page),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: AnimatedContainer(
                duration: morph,
                curve: Curves.easeOutBack,
                width: last ? c.maxWidth : _size,
                height: _size,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Progress ring around the round button; hidden once it stretches.
                    AnimatedOpacity(
                      opacity: last ? 0 : 1,
                      duration: const Duration(milliseconds: 150),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(end: (page + 1) / _slides.length),
                        duration: const Duration(milliseconds: 450),
                        curve: Curves.easeOutCubic,
                        builder: (context, v, _) => CustomPaint(painter: _RingPainter(v)),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(last ? 0 : 6),
                      child: Material(
                        color: RidoColors.coral600,
                        shape: const StadiumBorder(),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: last ? onFinish : onNext,
                          child: Semantics(
                            button: true,
                            label: last ? 'Get started' : 'Next',
                            child: ExcludeSemantics(
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 220),
                                transitionBuilder: (child, a) => FadeTransition(
                                  opacity: a,
                                  child: ScaleTransition(scale: a, child: child),
                                ),
                                child: last
                                    ? Row(
                                        key: const ValueKey('start'),
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            'Get started',
                                            style: context.type.button.copyWith(color: RidoColors.surface),
                                          ),
                                          const SizedBox(width: RidoSpacing.s),
                                          const Icon(Symbols.arrow_forward_rounded, color: RidoColors.surface),
                                        ],
                                      )
                                    : const Center(
                                        key: ValueKey('next'),
                                        child: Icon(Symbols.arrow_forward_rounded, color: RidoColors.surface),
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.value);
  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(1.5, 1.5, size.width - 3, size.height - 3);
    final track = Paint()
      ..color = RidoColors.coral100
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawOval(rect, track);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * value,
      false,
      track
        ..color = RidoColors.coral600
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.value != value;
}

class _Dots extends StatelessWidget {
  const _Dots({required this.page});
  final int page;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Slide ${page + 1} of ${_slides.length}',
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < _slides.length; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutBack,
            margin: const EdgeInsets.only(right: RidoSpacing.s),
            width: i == page ? 28 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == page ? RidoColors.coral600 : RidoColors.divider,
              borderRadius: RidoRadii.pillRadius,
            ),
          ),
      ],
    ),
  );
}
