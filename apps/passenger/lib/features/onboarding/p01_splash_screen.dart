import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

import '../../router/routes.dart';
import 'widgets/font_safe_wordmark.dart';

/// P-01 Splash: coral background, white "rido" wordmark and the tagline.
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

  void _next() {
    if (!mounted) return;
    final auth = ref.read(authRepositoryProvider);
    if (!auth.hasSeenOnboarding) {
      context.go(Routes.onboarding);
    } else {
      context.go(auth.isLoggedIn ? Routes.ride : Routes.login);
    }
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
        backgroundColor: RidoColors.coral500,
        body: SafeArea(
          child: Stack(
            children: [
              const Center(
                child: FontSafeWordmark(size: 84, color: RidoColors.surface, dotColor: RidoColors.navy900),
              ),
              Positioned(
                left: RidoSpacing.xl,
                right: RidoSpacing.xl,
                bottom: RidoSpacing.xxl,
                child: Text(
                  'Fair rides. Full fare to your driver.',
                  textAlign: TextAlign.center,
                  style: t.body.copyWith(color: RidoColors.surface),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
