// S-13 daily selfie check: the map behind it shows where the driver is, never a built-in city.
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';
import 'package:tamiltaxi_driver/router/routes.dart';
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
}
