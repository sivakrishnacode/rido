import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  if (kUseLiveApi) {
    // Real backend: API repositories, trips over Socket.IO, routes from the server (Google stays server-side).
    TtClock.useRealDate();
    final session = await ApiSession.load();
    final api = ApiClient(baseUrl: kApiBaseUrl, session: session);
    RoadRouter.backend = backendRouter(api);
    // Push notifications (FCM); null when this build has no google-services.json.
    final push = await TtPush.create(api, app: PushApp.passenger);
    runApp(ProviderScope(overrides: liveApiOverrides(api, push: push), child: const TtPassengerApp()));
    return;
  }
  // Seed data + trip simulator (--dart-define=TT_LIVE_API=false). Road-following routes for the demo
  // trips (falls back to curved lines offline).
  RoadRouter.prefetchDemoRoutes();
  runApp(const ProviderScope(child: TtPassengerApp()));
}
