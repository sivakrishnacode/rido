import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';
import 'package:tamiltaxi_ui/tamiltaxi_ui.dart';

import '../../router/routes.dart';
import '../../state/session_actions.dart';

/// P-01 Splash: coral background, white "tamiltaxi" wordmark and the tagline.
/// After [SimTimings.splash] it routes to onboarding, sign-in or Home.
class P01SplashScreen extends ConsumerStatefulWidget {
  const P01SplashScreen({super.key, this.showcase = false});

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  @override
  ConsumerState<P01SplashScreen> createState() => _P01SplashScreenState();
}

class _P01SplashScreenState extends ConsumerState<P01SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (!widget.showcase) {
      _timer = Timer(ref.read(simTimingProvider)(SimTimings.splash), _next);
    }
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: TtColors.coral500,
        body: SafeArea(
          child: Stack(
            children: [
              const Center(
                child: TtWordmark(size: 84, color: TtColors.surface),
              ),
              Positioned(
                left: TtSpacing.xl,
                right: TtSpacing.xl,
                bottom: TtSpacing.xxl,
                child: Text(
                  'Fair rides. Full fare to your driver.',
                  textAlign: TextAlign.center,
                  style: t.body.copyWith(color: TtColors.surface),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
