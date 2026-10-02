// S-13 daily selfie check: the map behind it shows where the driver is, never a built-in city. Live, the server asks
// for it when going online; the front-camera photo is checked by the server, a pass goes online, a miss says why
// with Retake.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';
import 'package:tamiltaxi_driver/common/camera.dart';
import 'package:tamiltaxi_driver/features/home/d13_home_screen.dart';
import 'package:tamiltaxi_driver/features/states/s13_selfie_check_screen.dart';
import 'package:tamiltaxi_driver/router/routes.dart';
import 'package:tamiltaxi_driver/state/driver_session.dart';
import 'package:tamiltaxi_ui/tamiltaxi_ui.dart';

import 'support/harness.dart';
import 'support/live_fakes.dart';

const _signedIn = {'tamiltaxi.accessToken': 'token', 'tamiltaxi.driverId': 'd1'};

void main() {
  testWidgets('live with no GPS fix yet: the map shows the service city', (tester) async {
    final rig = await LiveRig.create(
      prefs: _signedIn,
      client: MockClient((_) async => http.Response('{"message":"Not here"}', 404, headers: {'content-type': 'application/json'})),
    );
    final container = await pumpRoute(tester, Routes.selfieCheck, overrides: rig.overrides);
    expect(tester.widget<TtMap>(find.byType(TtMap)).center, CityDefaults.center);
    await closeApp(tester, container);
  });

  testWidgets('demo: the map shows the demo car', (tester) async {
    final container = await pumpRoute(tester, Routes.selfieCheck);
    expect(tester.widget<TtMap>(find.byType(TtMap)).center, Seed.driverHome);
    await closeApp(tester, container);
  });

  testWidgets('live: the server asks for the selfie; a miss says why with Retake, a pass goes online', (tester) async {
    final rig = await LiveRig.create(
      prefs: _signedIn,
      client: MockClient((_) async => http.Response('{"message":"Not here"}', 404, headers: {'content-type': 'application/json'})),
    );
    rig.jobs
      ..selfieRequired = true
      ..selfieAnswers.add(const ApiException(422, "We couldn't match your face with your identity check. Retake it in good light"));
    var shots = 0;
    final container = await pumpRoute(tester, Routes.home, overrides: [
      ...rig.overrides,
      photoCameraProvider.overrideWithValue(({bool front = false}) async {
        expect(front, isTrue);
        shots++;
        return (bytes: Uint8List.fromList(_png), name: 'selfie.jpg');
      }),
    ]);

    // No local "once per session" gate in live mode: Home asks the server, which wants the selfie.
    await tester.tap(find.text('GO ONLINE').hitTestable().first);
    await _advance(tester);
    expect(find.byType(S13SelfieCheckScreen), findsOneWidget);
    expect(find.text('We match it with your ID check selfie'), findsOneWidget);

    await tester.tap(find.text('Take selfie').hitTestable());
    await _advance(tester);
    expect(find.textContaining("We couldn't match your face"), findsOneWidget);
    expect(find.text('Retake selfie'), findsOneWidget);
    expect(container.read(driverSessionProvider).online, isFalse);

    await tester.tap(find.text('Retake selfie').hitTestable());
    await _advance(tester, const Duration(seconds: 2));
    expect(shots, 2);
    expect(rig.jobs.selfieChecks, 2);
    expect(container.read(driverSessionProvider).online, isTrue);
    expect(find.byType(D13HomeScreen), findsOneWidget);
    expect(find.text("Selfie verified. You're online"), findsOneWidget);
    await closeApp(tester, container);
  });

  testWidgets('live: backing out of the camera sends nothing', (tester) async {
    final rig = await LiveRig.create(prefs: _signedIn);
    final container = await pumpRoute(tester, Routes.selfieCheck, overrides: [
      ...rig.overrides,
      photoCameraProvider.overrideWithValue(({bool front = false}) async => null),
    ]);
    await tester.tap(find.text('Take selfie').hitTestable());
    await _advance(tester);
    expect(rig.jobs.selfieChecks, 0);
    expect(find.byType(S13SelfieCheckScreen), findsOneWidget);
    await closeApp(tester, container);
  });
}

Future<void> _advance(WidgetTester tester, [Duration total = const Duration(seconds: 1)]) async {
  for (var t = Duration.zero; t < total; t += const Duration(milliseconds: 100)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// A 1×1 PNG (the camera's photo).
const _png = [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, //
  0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41, //
  0x54, 0x78, 0x9C, 0x63, 0xF8, 0xCF, 0xC0, 0xF0, 0x1F, 0x00, 0x05, 0x00, 0x01, 0xFF, 0x89, 0x99, 0x3D, 0x1D, 0x00, 0x00, //
  0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
];
