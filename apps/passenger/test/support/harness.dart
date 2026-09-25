import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rido_passenger/app.dart';
import 'package:rido_passenger/router/app_router.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

/// Test set-up shared by every test: no network tiles, bundled fonts, phone-sized view.
const shotKey = ValueKey('rido-shot');
bool _fontsLoaded = false;

/// Loads the Material Symbols font (package fonts are not auto-loaded in tests).
Future<void> loadTestFonts() async {
  if (_fontsLoaded) return;
  _fontsLoaded = true;
  RidoMap.tilesEnabled = false;
  RoadRouter.enabled = false;
  GoogleMapsConfig.enabled = false;
  GoogleFonts.config.allowRuntimeFetching = false;
  final loader = FontLoader('packages/material_symbols_icons/MaterialSymbolsRounded')
    ..addFont(rootBundle.load('packages/material_symbols_icons/lib/fonts/MaterialSymbolsRounded.ttf'));
  await loader.load();
}

/// Sets a 390 × 844 phone at 2x (or [width] logical px wide for overflow checks).
void usePhone(WidgetTester tester, {double width = 390, double height = 844}) {
  tester.view.physicalSize = Size(width * 2, height * 2);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

/// Pumps the real app at [location] (any route path).
Future<ProviderContainer> pumpRoute(
  WidgetTester tester,
  String location, {
  List<Override> overrides = const [],
  double width = 390,
}) async {
  await loadTestFonts();
  usePhone(tester, width: width);
  final container = ProviderContainer(overrides: overrides);
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: RepaintBoundary(key: shotKey, child: RidoPassengerApp(router: createPassengerRouter(initialLocation: location))),
    ),
  );
  await tester.pump(const Duration(milliseconds: 50));
  await tester.runAsync(() => GoogleFonts.pendingFonts());
  await tester.pump(const Duration(milliseconds: 900));
  return container;
}

/// Saves what is on screen as a PNG (780 × 1688), e.g. to compare with docs/design/*.png.
Future<void> saveScreenshot(WidgetTester tester, String path) async {
  await tester.runAsync(() async {
    final ro = tester.firstRenderObject<RenderRepaintBoundary>(find.byKey(shotKey));
    final ui.Image image = await ro.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File(path)
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}
