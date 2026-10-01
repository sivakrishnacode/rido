// Dev tool: renders the P-01 intro (2 s) as PNG frames at 1080 × 1920, 30 fps, e.g. for a preview video:
//
//   flutter test test/tool/intro_frames_test.dart --dart-define=OUT_DIR=/tmp/intro
//   ffmpeg -framerate 30 -i /tmp/intro/%03d.png -pix_fmt yuv420p -c:v libx264 intro.mp4
//
// Skipped when OUT_DIR is not given, so it never runs in normal test runs.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';
import 'package:tamiltaxi_passenger/app.dart';
import 'package:tamiltaxi_passenger/router/app_router.dart';
import 'package:tamiltaxi_passenger/router/routes.dart';

import '../support/harness.dart';

const _outDir = String.fromEnvironment('OUT_DIR');
const _fps = 30;

void main() {
  testWidgets('P-01 intro frames', (tester) async {
    await loadTestFonts();
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: RepaintBoundary(
          key: shotKey,
          child: TtPassengerApp(router: createPassengerRouter(initialLocation: Routes.splash)),
        ),
      ),
    );
    await tester.runAsync(() => GoogleFonts.pendingFonts());
    final frames = SimTimings.intro.inMilliseconds * _fps ~/ 1000;
    for (var i = 0; i <= frames; i++) {
      await tester.runAsync(() async {
        final ro = tester.firstRenderObject<RenderRepaintBoundary>(find.byKey(shotKey));
        final ui.Image image = await ro.toImage(pixelRatio: 3);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('$_outDir/${i.toString().padLeft(3, '0')}.png')
          ..createSync(recursive: true)
          ..writeAsBytesSync(bytes!.buffer.asUint8List());
      });
      if (i < frames) await tester.pump(const Duration(microseconds: 1000000 ~/ _fps));
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 1));
  }, skip: _outDir.isEmpty);
}
