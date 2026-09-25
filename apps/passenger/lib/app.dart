import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rido_ui/rido_ui.dart';

import 'router/app_router.dart';

/// The passenger app root. [router] is injectable for tests.
class RidoPassengerApp extends ConsumerStatefulWidget {
  const RidoPassengerApp({super.key, this.router});
  final GoRouter? router;

  @override
  ConsumerState<RidoPassengerApp> createState() => _RidoPassengerAppState();
}

class _RidoPassengerAppState extends ConsumerState<RidoPassengerApp> {
  late final GoRouter _router = widget.router ?? createPassengerRouter();

  @override
  Widget build(BuildContext context) => MaterialApp.router(
        title: 'Rido',
        debugShowCheckedModeBanner: false,
        theme: RidoTheme.light(),
        themeMode: ThemeMode.light,
        routerConfig: _router,
      );
}
