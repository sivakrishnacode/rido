import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rido_data/rido_data.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  // Road-following routes for the demo trips (falls back to curved lines offline).
  RoadRouter.prefetchDemoRoutes();
  runApp(const ProviderScope(child: RidoPassengerApp()));
}
