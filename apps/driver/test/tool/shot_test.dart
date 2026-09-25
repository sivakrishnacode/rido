// Dev tool: renders one route to a PNG so it can be compared with docs/design/*.png.
//
//   flutter test test/tool/shot_test.dart \
//     --dart-define=ROUTE=/ride/choose-vehicle --dart-define=OUT=/tmp/p10.png \
//     [--dart-define=WAIT_MS=1500] [--dart-define=TAP=Book]
//
// Skipped when ROUTE is not given, so it never runs in normal test runs.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/harness.dart';

const _route = String.fromEnvironment('ROUTE');
const _out = String.fromEnvironment('OUT', defaultValue: 'build/shot.png');
const _waitMs = int.fromEnvironment('WAIT_MS', defaultValue: 600);
const _tap = String.fromEnvironment('TAP');
const _width = int.fromEnvironment('WIDTH', defaultValue: 390);

void main() {
  testWidgets('screenshot $_route', (tester) async {
    await pumpRoute(tester, _route, width: _width.toDouble());
    await tester.pump(const Duration(milliseconds: _waitMs));
    if (_tap.isNotEmpty) {
      await tester.tap(find.text(_tap).first);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
    }
    await saveScreenshot(tester, _out);
    // Let pending timers finish so the test can end cleanly.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 60));
  }, skip: _route.isEmpty);
}
