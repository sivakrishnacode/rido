import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

import 'router/app_router.dart';
import 'router/routes.dart';
import 'state/driver_account.dart';
import 'state/driver_session.dart';

/// The driver app root. [router] is injectable for tests.
///
/// With the live API it also: sends the driver to log in when the token is rejected (401), shows the
/// session's notices (e.g. "Priya cancelled the ride") and closes the job screens when a job ends from
/// the other side, and tells the session when the app comes back to the foreground.
class RidoDriverApp extends ConsumerStatefulWidget {
  const RidoDriverApp({super.key, this.router});
  final GoRouter? router;

  @override
  ConsumerState<RidoDriverApp> createState() => _RidoDriverAppState();
}

class _RidoDriverAppState extends ConsumerState<RidoDriverApp> with WidgetsBindingObserver {
  late final GoRouter _router = widget.router ?? createDriverRouter();
  StreamSubscription<void>? _unauthorized;

  /// Routes where a signed-out driver already is (no redirect, no snack).
  static const _authPaths = {Routes.splash, Routes.welcome, '/auth/phone', '/auth/otp'};

  bool get _live => ref.read(isLiveApiProvider);

  @override
  void initState() {
    super.initState();
    if (!_live) return;
    WidgetsBinding.instance.addObserver(this);
    _unauthorized = ref.read(apiClientProvider).onUnauthorized.listen((_) => _signedOut());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _unauthorized?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) ref.read(driverSessionProvider.notifier).onAppResumed();
  }

  String get _path => _router.routerDelegate.currentConfiguration.uri.path;

  void _signedOut() {
    if (!mounted) return;
    ref.read(realtimeProvider).disconnect();
    resetDriverData(ref);
    if (_authPaths.contains(_path)) return;
    _router.go(Routes.welcome);
    final context = rootNavigatorKey.currentContext;
    if (context != null) showRidoSnack(context, 'Your session ended. Please log in again.');
  }

  void _onNotice(SessionNotice notice) {
    if (notice.jobEnded && _path.startsWith('/driver/')) _router.go(Routes.home);
    // Let the navigation settle so the snack shows on the new screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = rootNavigatorKey.currentContext;
      if (context != null) showRidoSnack(context, notice.message);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_live) {
      ref.listen(driverSessionProvider.select((s) => s.notice), (prev, next) {
        if (next != null && !identical(prev, next)) _onNotice(next);
      });
    }
    return MaterialApp.router(
      title: 'Rido Driver',
      debugShowCheckedModeBanner: false,
      theme: RidoTheme.light(),
      themeMode: ThemeMode.light,
      routerConfig: _router,
    );
  }
}
