import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

import '../../router/routes.dart';
import 'widgets/onboarding_scenes.dart';

class _Slide {
  const _Slide(this.title, this.body, {this.caption});
  final String title;
  final String body;
  final String? caption;
}

const _slides = [
  _Slide('Lower fares, every ride', 'Bike, auto or cab across Coimbatore — with no commission added to your fare.'),
  _Slide(
    'Your driver keeps 100%',
    'Drivers pay Rido a small monthly plan. Every rupee you pay goes to them.',
    caption: 'Rido takes 0% commission.',
  ),
  _Slide(
    'Rides and parcels in one app',
    'Book a ride to Brookefields or send a tiffin to RS Puram — same app, same fair prices.',
  ),
];

/// P-02 Onboarding: three slides (P-02a/b/c) with page dots, Skip and "Get started".
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

  void _nextPage() => _pages.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Scaffold(
      backgroundColor: RidoColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 64,
              child: Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: RidoSpacing.s),
                  child: AnimatedOpacity(
                    opacity: _last ? 0 : 1,
                    duration: const Duration(milliseconds: 200),
                    child: IgnorePointer(
                      ignoring: _last,
                      child: TextButton(
                        onPressed: _finish,
                        style: TextButton.styleFrom(
                          foregroundColor: RidoColors.navy700,
                          minimumSize: const Size(64, 48),
                        ),
                        child: Text('Skip', style: t.bodySemibold.copyWith(color: RidoColors.navy700)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pages,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) => _SlideView(index: i, slide: _slides[i]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(RidoSpacing.l, RidoSpacing.s, RidoSpacing.l, RidoSpacing.xl),
              child: _last
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _Dots(page: _page),
                        const SizedBox(height: RidoSpacing.xl),
                        RidoButton(label: 'Get started', onPressed: _finish),
                      ],
                    )
                  : Row(
                      children: [
                        _Dots(page: _page),
                        const Spacer(),
                        Tooltip(
                          message: 'Next',
                          child: Material(
                            color: RidoColors.coral600,
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: _nextPage,
                              child: const SizedBox(
                                width: 56,
                                height: 56,
                                child: Icon(Symbols.arrow_forward_rounded, color: RidoColors.surface),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.index, required this.slide});
  final int index;
  final _Slide slide;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return LayoutBuilder(
      builder: (context, c) {
        final sceneH = (c.maxHeight * 0.58).clamp(200.0, 400.0);
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: RidoSpacing.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: sceneH,
                width: double.infinity,
                child: OnboardingScene(index: index),
              ),
              const SizedBox(height: RidoSpacing.xxl),
              Padding(
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
            ],
          ),
        );
      },
    );
  }
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
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(right: RidoSpacing.s),
            width: i == page ? 24 : 8,
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
