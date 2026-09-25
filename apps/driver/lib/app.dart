import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rido_ui/rido_ui.dart';

import 'router/app_router.dart';

/// The driver app root. [router] is injectable for tests.
class RidoDriverApp extends ConsumerStatefulWidget {
  const RidoDriverApp({super.key, this.router});
  final GoRouter? router;

  @override
  ConsumerState<RidoDriverApp> createState() => _RidoDriverAppState();
}

class _RidoDriverAppState extends ConsumerState<RidoDriverApp> {
  late final GoRouter _router = widget.router ?? createDriverRouter();

  @override
  Widget build(BuildContext context) => MaterialApp.router(
        title: 'Rido Driver',
        debugShowCheckedModeBanner: false,
        theme: RidoTheme.light(),
        themeMode: ThemeMode.light,
        routerConfig: _router,
      );
}
