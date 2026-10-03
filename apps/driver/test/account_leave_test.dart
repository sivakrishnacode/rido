// D-26 Log out (live): one offline call with a progress state that can't be tapped twice. There is no Delete
// account row: drivers ask support (records are kept 6 months for police enquiries).
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tamiltaxi_driver/features/onboarding/d02_welcome_screen.dart';
import 'package:tamiltaxi_driver/router/routes.dart';

import 'support/harness.dart';
import 'support/live_fakes.dart';

const _signedIn = {'tamiltaxi.accessToken': 'token', 'tamiltaxi.driverId': 'd1'};

const _driver = {
  'id': 'd1',
  'status': 'APPROVED',
  'vehicleKind': 'BIKE',
  'vehicleModel': 'Splendor',
  'vehicleColor': 'Black',
  'plate': 'TN 37 AB 4521',
  'upiId': 'anbu@okaxis',
  'user': {'name': 'Anbu R', 'phone': '+919843012345'},
};

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

/// The API for D-26: the driver, no contacts, no documents; [onOffline] answers going offline.
MockClient _api({required Future<http.Response> Function() onOffline, List<String>? log}) =>
    MockClient((req) async {
      log?.add('${req.method} ${req.url.path}');
      final path = req.url.path;
      if (req.method == 'POST' && path == '/v1/drivers/me/offline') return onOffline();
      if (path == '/v1/drivers/me') return _json(_driver);
      if (path == '/v1/me') return _json({'emergencyContacts': []});
      if (path == '/v1/drivers/me/documents') return _json([]);
      if (path == '/v1/kyc/me') return _json({'isEnabled': false, 'status': 'NOT_STARTED'});
      return _json({'message': 'Not here'}, 404);
    });

Future<void> _advance(WidgetTester tester, [Duration total = const Duration(seconds: 1)]) async {
  for (var t = Duration.zero; t < total; t += const Duration(milliseconds: 100)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _tapRow(WidgetTester tester, String text) async {
  await tester.dragUntilVisible(find.text(text), find.byType(ListView), const Offset(0, -200));
  await tester.pump();
  await tester.tap(find.text(text).hitTestable());
  await _advance(tester, const Duration(milliseconds: 500));
}

void main() {
  testWidgets('log out: one offline call, a progress state, no double tap, then Welcome', (tester) async {
    final release = Completer<http.Response>();
    final log = <String>[];
    final rig = await LiveRig.create(prefs: _signedIn, client: _api(onOffline: () => release.future, log: log));
    final container = await pumpRoute(tester, Routes.account, overrides: rig.overrides);
    await _advance(tester);
    expect(find.text('Anbu R'), findsOneWidget);

    await _tapRow(tester, 'Log out');
    await tester.tap(find.text('Log out').last); // The dialog's button.
    await _advance(tester);
    expect(find.text('Logging out…'), findsOneWidget);
    await tester.tap(find.text('Logging out…'));
    await _advance(tester);

    release.complete(_json({}));
    await _advance(tester);
    expect(find.byType(D02WelcomeScreen), findsOneWidget);
    expect(log.where((c) => c == 'POST /v1/drivers/me/offline'), hasLength(1));
    expect(rig.jobs.calls, isNot(contains('offline')));
    expect(rig.api.session.isLoggedIn, isFalse);
    await closeApp(tester, container);
  });

  testWidgets('no Delete account row', (tester) async {
    final rig = await LiveRig.create(prefs: _signedIn, client: _api(onOffline: () async => _json({})));
    final container = await pumpRoute(tester, Routes.account, overrides: rig.overrides);
    await _advance(tester);
    await tester.dragUntilVisible(find.text('Log out'), find.byType(ListView), const Offset(0, -200));
    expect(find.text('Delete account'), findsNothing);
    expect(find.text('Refer a driver'), findsNothing);
    await closeApp(tester, container);
  });
}
