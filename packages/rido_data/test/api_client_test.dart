import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rido_data/rido_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A client whose first request fails like a pooled connection the server already closed.
MockClient _dropsFirst(List<String> calls) {
  var n = 0;
  return MockClient((req) async {
    calls.add('${req.method} ${req.url.path}');
    if (n++ == 0) throw http.ClientException('Connection closed before full header was received');
    return http.Response('{"ok":true}', 200, headers: {'content-type': 'application/json'});
  });
}

Future<ApiClient> _api(http.Client client) async {
  SharedPreferences.setMockInitialValues({});
  return ApiClient(baseUrl: 'http://api.test/v1', session: await ApiSession.load(), client: client);
}

void main() {
  test('reads are retried once after a dropped connection', () async {
    final calls = <String>[];
    final api = await _api(_dropsFirst(calls));
    expect(await api.get('/trips'), {'ok': true});
    expect(calls, ['GET /v1/trips', 'GET /v1/trips']);
  });

  test('idempotent posts (quotes) are retried; bookings are not', () async {
    final calls = <String>[];
    final api = await _api(_dropsFirst(calls));
    expect(await api.post('/fares/quote', {'a': 1}, true), {'ok': true});
    expect(calls.length, 2);

    final bookings = <String>[];
    final api2 = await _api(_dropsFirst(bookings));
    await expectLater(api2.post('/trips', {'a': 1}), throwsA(isA<OfflineException>()));
    expect(bookings.length, 1);
  });

  test('two dropped connections in a row are offline', () async {
    final api = await _api(MockClient((_) async => throw http.ClientException('reset')));
    await expectLater(api.get('/trips'), throwsA(isA<OfflineException>()));
  });

  test('API errors carry the server message', () async {
    final api = await _api(MockClient((_) async => http.Response('{"message":["Enter a valid number plate"]}', 400)));
    await expectLater(api.post('/drivers', {}), throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Enter a valid number plate')));
  });

  test('TOO_FAR carries the distance and suggested reasons', () async {
    final api = await _api(MockClient((_) async => http.Response(
          '{"statusCode":422,"message":"You\'re 850 m from the pickup point","code":"TOO_FAR",'
          '"details":{"stop":"pickup","distanceM":850,"radiusM":250,"reasons":["Customer asked to meet here"]}}',
          422,
        )));
    try {
      await api.post('/trips/t1/arrived', {});
      fail('expected TOO_FAR');
    } on ApiException catch (e) {
      final far = e.tooFar!;
      expect(far.stop, 'pickup');
      expect(far.distanceM, 850);
      expect(far.radiusM, 250);
      expect(far.reasons, ['Customer asked to meet here']);
      expect(far.message, "You're 850 m from the pickup point");
    }
  });
}
