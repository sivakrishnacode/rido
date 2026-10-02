// D-26 Log out and Delete account (live): one offline call with a progress state that can't be tapped twice;
// deleting says what goes, shows a refusal (unfinished trip) and ends at Welcome once deleted.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tamiltaxi_driver/features/account/d26_account_screen.dart';
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

/// The API for D-26: the driver, no contacts, no documents; [onOffline] / [onDelete] answer those calls.
MockClient _api({required Future<http.Response> Function() onOffline, Future<http.Response> Function()? onDelete, List<String>? log}) =>
    MockClient((req) async {
      log?.add('${req.method} ${req.url.path}');
      final path = req.url.path;
      if (req.method == 'POST' && path == '/v1/drivers/me/offline') return onOffline();
      if (req.method == 'DELETE' && path == '/v1/me') return onDelete!();
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

  testWidgets('delete account: a refusal shows its message; once deleted, Welcome', (tester) async {
    var refuse = true;
    final log = <String>[];
    final rig = await LiveRig.create(
      prefs: _signedIn,
      client: _api(
        log: log,
        onOffline: () async => _json({}),
        onDelete: () async => refuse
            ? _json({'message': 'Finish or cancel your trip before deleting your account'}, 409)
            : http.Response('', 204),
      ),
    );
    final container = await pumpRoute(tester, Routes.account, overrides: rig.overrides);
    await _advance(tester);

    await _tapRow(tester, 'Delete account');
    expect(find.text('Delete your account?'), findsOneWidget);
    expect(find.textContaining('Trip records are kept for 3 years'), findsOneWidget);
    await tester.tap(find.text('Delete account').last);
    await _advance(tester);
    expect(find.text('Finish or cancel your trip before deleting your account'), findsOneWidget);
    expect(find.byType(D26AccountScreen), findsOneWidget);
    expect(rig.api.session.isLoggedIn, isTrue);

    refuse = false;
    await _advance(tester, const Duration(seconds: 4));
    await _tapRow(tester, 'Delete account');
    await tester.tap(find.text('Delete account').last);
    await _advance(tester);
    expect(find.byType(D02WelcomeScreen), findsOneWidget);
    expect(rig.api.session.isLoggedIn, isFalse);
    // A deleted account isn't told to go offline.
    expect(log, isNot(contains('POST /v1/drivers/me/offline')));
    await closeApp(tester, container);
  });
}
