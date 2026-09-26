import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

import 'router/app_router.dart';
import 'router/routes.dart';
import 'state/app_notice.dart';
import 'state/session_actions.dart';

/// The passenger app root. [router] is injectable for tests.
class RidoPassengerApp extends ConsumerStatefulWidget {
  const RidoPassengerApp({super.key, this.router});
  final GoRouter? router;

  @override
  ConsumerState<RidoPassengerApp> createState() => _RidoPassengerAppState();
}

class _RidoPassengerAppState extends ConsumerState<RidoPassengerApp> {
  late final GoRouter _router = widget.router ?? createPassengerRouter();
  StreamSubscription<void>? _unauthorized;

  @override
  void initState() {
    super.initState();
    // Live API: a rejected token (expired, or the account was blocked) sends the passenger to sign in.
    if (ref.read(isLiveApiProvider)) {
      _unauthorized = ref.read(apiClientProvider).onUnauthorized.listen((_) {
        if (!mounted) return;
        resetSignedInState(ref);
        ref.read(appNoticeProvider.notifier).show('Please sign in again', goTo: Routes.login);
      });
    }
  }

  @override
  void dispose() {
    _unauthorized?.cancel();
    super.dispose();
  }

  void _showNotice(AppNotice notice) {
    final goTo = notice.goTo;
    if (goTo != null) _router.go(goTo);
    final context = rootNavigatorKey.currentContext;
    if (context != null) showRidoSnack(context, notice.message);
  }

  @override
  Widget build(BuildContext context) {
    // Messages from controllers (e.g. the server cancelled the trip), shown wherever the passenger is.
    ref.listen(appNoticeProvider, (_, next) {
      if (next != null) _showNotice(next);
    });
    return MaterialApp.router(
      title: 'Rido',
      debugShowCheckedModeBanner: false,
      theme: RidoTheme.light(),
      themeMode: ThemeMode.light,
      routerConfig: _router,
    );
  }
}
