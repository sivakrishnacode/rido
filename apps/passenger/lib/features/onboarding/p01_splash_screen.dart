import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';
import 'package:tamiltaxi_ui/tamiltaxi_ui.dart';

import '../../router/routes.dart';
import '../../state/session_actions.dart';

/// P-01 Splash: coral background, the white "தமிழ் / Taxi" name (same art and place as the native
/// splash, so the hand-off is seamless) and the tagline.
///
/// A 2 s intro ([SimTimings.intro]) plays from the native splash's exact frame: the icon's kolam ring draws itself
/// round the name and its dots pop in, the lane dashes run along the x's flyover while the name gives a small
/// bounce, the ring fades out as it widens, and the tagline rises in. Then it routes to onboarding, sign-in or Home.
/// With "Remove animations" on it shows the last frame for [SimTimings.splash] instead.
class P01SplashScreen extends ConsumerStatefulWidget {
  const P01SplashScreen({super.key, this.showcase = false});

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  @override
  ConsumerState<P01SplashScreen> createState() => _P01SplashScreenState();
}

class _P01SplashScreenState extends ConsumerState<P01SplashScreen> with SingleTickerProviderStateMixin {
  static const _nameWidth = 122.0;
  Timer? _timer;
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: ref.read(simTimingProvider)(SimTimings.intro),
  );
  bool _started = false;

  // The timeline, as fractions of the intro.
  static const _ring = Interval(0.10, 0.45, curve: Curves.easeInOutCubic);
  static const _lanes = Interval(0.25, 0.60, curve: Curves.easeInOut);
  static const _fade = Interval(0.60, 0.80, curve: Curves.easeOut);
  static const _tagline = Interval(0.80, 1.0, curve: Curves.easeOut);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // Gallery: the last frame (tap to replay). Animations off: the last frame, then on as before.
    if (widget.showcase || MediaQuery.disableAnimationsOf(context)) {
      _intro.value = 1;
      if (!widget.showcase) _timer = Timer(ref.read(simTimingProvider)(SimTimings.splash), _next);
      return;
    }
    _intro.addStatusListener((status) {
      if (status == AnimationStatus.completed) _next();
    });
    _intro.forward();
  }

  Future<void> _next() async {
    if (!mounted) return;
    final auth = ref.read(authRepositoryProvider);
    if (!auth.hasSeenOnboarding) {
      context.go(Routes.onboarding);
      return;
    }
    if (!auth.isLoggedIn) {
      context.go(Routes.login);
      return;
    }
    if (!ref.read(isLiveApiProvider)) {
      context.go(Routes.ride);
      return;
    }
    // Live API: finish sign-up if the name was never set, then reopen an unfinished trip.
    try {
      final profile = await auth.profile();
      if (!mounted) return;
      if (profile.name.trim().isEmpty) {
        context.go(Routes.profileSetup);
        return;
      }
    } on ApiException {
      // Signed out by a 401 (the app root shows the login screen) or a server error: carry on to Home.
    } on OfflineException {
      // Home shows its offline states.
    }
    if (!mounted || !auth.isLoggedIn) return;
    final trip = await restoreActiveTrip(ref);
    if (!mounted) return;
    context.go(trip ?? Routes.ride);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: TtColors.coral500,
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          // Design gallery: tap to watch the intro again.
          onTap: widget.showcase ? () => _intro.forward(from: 0) : null,
          child: AnimatedBuilder(
            animation: _intro,
            builder: (context, _) {
              final v = _intro.value;
              final ring = _ring.transform(v);
              final lanes = _lanes.transform(v);
              final fade = _fade.transform(v);
              final tagline = _tagline.transform(v);
              return Stack(
                children: [
                  // The ring widens a little as it fades.
                  if (ring > 0 && fade < 1)
                    Center(
                      child: Opacity(
                        opacity: 1 - fade,
                        child: Transform.scale(
                          scale: 1 + 0.18 * fade,
                          child: KolamRing(nameWidth: _nameWidth, sweep: ring),
                        ),
                      ),
                    ),
                  // Centred on the whole window, like the native splash (drawable-nodpi/splash_logo.png, 130 dp
                  // wide). Two lane periods end where the dashes started, so the last frame is the plain logo.
                  Center(
                    child: Transform.scale(
                      scale: 1 + 0.05 * math.sin(math.pi * lanes),
                      child: TtAppName(width: _nameWidth, color: TtColors.surface, laneShift: 2 * lanes),
                    ),
                  ),
                  SafeArea(
                    child: Stack(
                      children: [
                        Positioned(
                          left: TtSpacing.xl,
                          right: TtSpacing.xl,
                          bottom: TtSpacing.xxl,
                          child: Opacity(
                            opacity: tagline,
                            child: Transform.translate(
                              offset: Offset(0, 12 * (1 - tagline)),
                              child: Text(
                                'Fair rides. Full fare to your driver.',
                                textAlign: TextAlign.center,
                                style: t.body.copyWith(color: TtColors.surface),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
