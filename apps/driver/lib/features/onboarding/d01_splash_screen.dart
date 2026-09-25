import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

import '../../router/routes.dart';
import 'widgets/signup_widgets.dart';

/// D-01 Splash: navy background, white wordmark and a coral "DRIVER" tag.
/// After 1.5 s: signed in → Home, otherwise → D-02 Welcome.
class D01SplashScreen extends ConsumerStatefulWidget {
  const D01SplashScreen({super.key, this.showcase = false});

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  @override
  ConsumerState<D01SplashScreen> createState() => _D01SplashScreenState();
}

class _D01SplashScreenState extends ConsumerState<D01SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.showcase) return;
    _timer = Timer(ref.read(simTimingProvider)(SimTimings.splash), () {
      if (!mounted) return;
      final loggedIn = ref.read(driverRepositoryProvider).isLoggedIn;
      context.go(loggedIn ? Routes.home : Routes.welcome);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: RidoColors.navy900,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Semantics(
                label: 'Rido Driver',
                child: const Column(
                  children: [
                    DriverWordmark(size: 84),
                    SizedBox(height: RidoSpacing.l),
                    DriverTag(large: true),
                  ],
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: RidoSpacing.xxl + RidoSpacing.s),
                child: Text('0% commission · Coimbatore',
                    textAlign: TextAlign.center,
                    style: context.type.body.copyWith(color: RidoColors.navy300)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
