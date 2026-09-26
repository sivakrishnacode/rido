import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rido_data/rido_data.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  if (kUseLiveApi) {
    // Real backend: API repositories, trips over Socket.IO, routes from the server (Google stays server-side).
    final session = await ApiSession.load();
    final api = ApiClient(baseUrl: kApiBaseUrl, session: session);
    RoadRouter.backend = backendRouter(api);
    // Push notifications (FCM); null when this build has no google-services.json.
    final push = await RidoPush.create(api, app: PushApp.passenger);
    runApp(ProviderScope(overrides: liveApiOverrides(api, push: push), child: const RidoPassengerApp()));
    return;
  }
  // Seed data + trip simulator (--dart-define=RIDO_LIVE_API=false). Road-following routes for the demo
  // trips (falls back to curved lines offline).
  RoadRouter.prefetchDemoRoutes();
  runApp(const ProviderScope(child: RidoPassengerApp()));
}
