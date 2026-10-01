import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';
import 'package:tamiltaxi_ui/tamiltaxi_ui.dart';

import '../../common/start_route.dart';
import '../../router/routes.dart';
import 'widgets/signup_widgets.dart';

/// D-01 Splash: navy background, the white "தமிழ் / Taxi" name (same art and place as the native splash)
/// and a coral "DRIVER" tag under it.
/// After 1.5 s: signed in → Home, otherwise → D-02 Welcome. With the live API a signed-in driver goes
/// where their application stands: Home (approved), D-07 (documents missing), D-10 (under review) or
/// S-09 (a document was rejected).
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
    _timer = Timer(ref.read(simTimingProvider)(SimTimings.splash), _route);
  }

  Future<void> _route() async {
    if (!mounted) return;
    final repo = ref.read(driverRepositoryProvider);
    if (!repo.isLoggedIn) {
      context.go(Routes.welcome);
      return;
    }
    var route = Routes.home;
    if (ref.read(isLiveApiProvider)) {
      try {
        route = await driverStartRoute(repo, ref.read(identityRepositoryProvider));
      } on ApiException catch (e) {
        // 401: the session was cleared; anything else: Home shows what it can.
        route = e.status == 401 ? Routes.welcome : Routes.home;
      }
    }
    if (mounted) context.go(route);
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
        backgroundColor: TtColors.navy900,
        body: Stack(
          children: [
            // The name sits exactly where the native splash drew it (window centre); the tag hangs below it.
            Semantics(
              label: 'Tamil Taxi Driver',
              child: const Column(
                children: [
                  Expanded(child: SizedBox.shrink()),
                  TtAppName(width: 122),
                  Expanded(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: EdgeInsets.only(top: TtSpacing.l),
                        child: DriverTag(large: true),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: TtSpacing.xxl + TtSpacing.s),
                  child: Text('0% commission',
                      textAlign: TextAlign.center,
                      style: context.type.body.copyWith(color: TtColors.navy300)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
