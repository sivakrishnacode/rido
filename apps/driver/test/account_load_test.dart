// Live account screens never fall back to the seed driver: while the profile loads they wait, when it fails they say
// so with Retry, and Save never sends seeded details over the real driver.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';
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

class _Api {
  bool profileUp = false;
  bool contactsUp = true;
  final calls = <String>[];

  MockClient get client => MockClient((req) async {
        final path = req.url.path;
        calls.add('${req.method} $path');
        if (path == '/v1/drivers/me') {
          if (req.method == 'PATCH') return _json(_driver);
          return profileUp ? _json(_driver) : _json({'message': 'Server is busy'}, 503);
        }
        if (path == '/v1/me') return contactsUp ? _json({'emergencyContacts': []}) : _json({'message': 'Server is busy'}, 503);
        if (path == '/v1/drivers/me/documents') return _json([]);
        if (path == '/v1/kyc/me') return _json({'isEnabled': false, 'status': 'NOT_STARTED'});
        if (path == '/v1/subscriptions/me') return _json({'message': 'Server is busy'}, 503);
        return _json({'message': 'Not here'}, 404);
      });
}

Future<void> _advance(WidgetTester tester, [Duration total = const Duration(seconds: 1)]) async {
  for (var t = Duration.zero; t < total; t += const Duration(milliseconds: 100)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('D-26: a failed profile shows Retry, never the seed driver; Retry loads it', (tester) async {
    final api = _Api()..contactsUp = false;
    final rig = await LiveRig.create(prefs: _signedIn, client: api.client);
    final container = await pumpRoute(tester, Routes.account, overrides: rig.overrides);
    await _advance(tester);
    expect(find.text(Seed.karthik.name), findsNothing);
    expect(find.text("Profile didn't load"), findsOneWidget);
    expect(find.text("Couldn't load it. Tap to try again"), findsOneWidget);

    api.profileUp = true;
    await tester.tap(find.text('Retry'));
    await _advance(tester);
    expect(find.text('Anbu R'), findsOneWidget);
    expect(find.text('anbu@okaxis'), findsOneWidget);
    await closeApp(tester, container);
  });

  testWidgets('UPI ID and Vehicle details: no seeded form, no save, until the profile loads', (tester) async {
    final api = _Api();
    final rig = await LiveRig.create(prefs: _signedIn, client: api.client);
    final container = await pumpRoute(tester, Routes.upiId, overrides: rig.overrides);
    await _advance(tester);
    expect(find.text(Seed.karthik.upiId), findsNothing);
    expect(find.text('Save'), findsNothing);
    expect(find.text('Retry'), findsOneWidget);

    api.profileUp = true;
    await tester.tap(find.text('Retry'));
    await _advance(tester);
    expect(find.text('anbu@okaxis'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(api.calls, isNot(contains('PATCH /v1/drivers/me')));
    await closeApp(tester, container);
  });

  testWidgets('Vehicle details while the profile fails: Retry, not Karthik\'s bike', (tester) async {
    final api = _Api();
    final rig = await LiveRig.create(prefs: _signedIn, client: api.client);
    final container = await pumpRoute(tester, Routes.vehicleDetails, overrides: rig.overrides);
    await _advance(tester);
    expect(find.text(Seed.karthik.plate), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
    api.profileUp = true;
    await tester.tap(find.text('Retry'));
    await _advance(tester);
    expect(find.text('TN 37 AB 4521'), findsOneWidget);
    expect(find.text('Splendor'), findsOneWidget);
    await closeApp(tester, container);
  });

  testWidgets('D-24: a plan that fails to load shows Retry instead of a skeleton forever', (tester) async {
    final api = _Api()..profileUp = true;
    final rig = await LiveRig.create(prefs: _signedIn, client: api.client);
    final container = await pumpRoute(tester, Routes.plan, overrides: rig.overrides);
    await _advance(tester);
    expect(find.text("Couldn't load your plan"), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    await closeApp(tester, container);
  });
}
