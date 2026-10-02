import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';

void main() {
  test('parses GET /app-config with the monthly cost and its breakdown', () {
    final c = AppConfig.fromJson({
      'driverPlansEnabled': false,
      'supportPhone': '+91 422 111 2222',
      'contribute': {
        'upiId': 'tamiltaxi@okaxis',
        'payeeName': 'Tamil Taxi',
        'note': 'Keep Tamil Taxi free',
        'monthlyCost': {
          'totalInr': 6000,
          'items': [
            {'label': 'Servers & database', 'amountInr': 2500},
            {'label': 'Maps', 'amountInr': 3500},
          ],
        },
      },
    });
    expect(c.driverPlansEnabled, isFalse);
    expect(c.contribute.canPay, isTrue);
    expect(c.contribute.monthlyCostInr, 6000);
    expect(c.contribute.costItems.map((i) => '${i.label}=${i.amountInr}'), ['Servers & database=2500', 'Maps=3500']);
  });

  test('no UPI ID or cost entered: no pay button, cost hidden, default name and note', () {
    final c = AppConfig.fromJson({
      'driverPlansEnabled': true,
      'contribute': {'upiId': '', 'payeeName': '', 'note': '', 'monthlyCost': null},
    });
    expect(c.driverPlansEnabled, isTrue);
    expect(c.contribute.canPay, isFalse);
    expect(c.contribute.monthlyCostInr, isNull);
    expect(c.contribute.payeeName, 'Tamil Taxi');
    expect(c.contribute.note, AppConfig.defaultNote);
  });

  test('UPI link encodes spaces as %20 and adds the amount only when chosen', () {
    const info = ContributeInfo(upiId: 'tamiltaxi@okaxis', payeeName: 'Tamil Taxi Coimbatore', note: '');
    expect(info.payUri(amountInr: 50).toString(),
        'upi://pay?pa=tamiltaxi@okaxis&pn=Tamil%20Taxi%20Coimbatore&am=50&cu=INR&tn=Contribution%20to%20Tamil%20Taxi%20Coimbatore');
    expect(info.payUri().queryParameters.containsKey('am'), isFalse);
  });

  testWidgets('a failed app config or city list is fetched again, not kept for the session', (tester) async {
    final calls = <String, int>{};
    SharedPreferences.setMockInitialValues({});
    final session = await ApiSession.load();
    final api = ApiClient(
      baseUrl: 'http://api.test/v1',
      session: session,
      client: MockClient((req) async {
        // Each path fails twice (the request and its one retry): offline at first.
        final n = calls[req.url.path] = (calls[req.url.path] ?? 0) + 1;
        if (n <= 2) throw http.ClientException('no network');
        return req.url.path.endsWith('/cities')
            ? http.Response('[{"id":"c1","name":"Madurai","state":"Tamil Nadu","centerLat":9.93,"centerLng":78.12}]', 200)
            : http.Response('{"supportPhone":"+91 98430 12345"}', 200);
      }),
    );
    final container = ProviderContainer(overrides: [isLiveApiProvider.overrideWithValue(true), apiClientProvider.overrideWithValue(api)]);
    Future<void> settle() async {
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
    }

    container.listen(appConfigProvider, (_, _) {});
    await settle();
    expect(container.read(appConfigProvider).value?.supportPhone, AppConfig.fallback.supportPhone, reason: 'offline: the fallback');
    await tester.pump(const Duration(seconds: 30));
    await settle();
    expect(container.read(appConfigProvider).value?.supportPhone, '+91 98430 12345');

    container.listen(serviceCitiesProvider, (_, _) {});
    await settle();
    expect(container.read(serviceCitiesProvider).value, isEmpty);
    await tester.pump(const Duration(seconds: 30));
    await settle();
    expect(container.read(serviceCitiesProvider).value?.single.name, 'Madurai');
    container.dispose();
  });
}
