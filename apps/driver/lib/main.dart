import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rido_data/rido_data.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  if (!kUseLiveApi) {
    // Seed data + trip simulator (--dart-define=RIDO_LIVE_API=false). Road-following routes for the demo
    // trips (falls back to curved lines offline).
    RoadRouter.prefetchDemoRoutes();
    runApp(const ProviderScope(child: RidoDriverApp()));
    return;
  }
  // Rido API: repositories over HTTP, offers and job updates over Socket.IO, routes from the backend
  // (no Google key in the app). A 401 sends the driver back to log in (see RidoDriverApp).
  final session = await ApiSession.load();
  final api = ApiClient(baseUrl: kApiBaseUrl, session: session);
  RoadRouter.backend = backendRouter(api);
  runApp(ProviderScope(overrides: liveApiOverrides(api), child: const RidoDriverApp()));
}
