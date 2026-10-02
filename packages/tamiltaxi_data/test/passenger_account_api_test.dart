import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';

const _json = {'content-type': 'application/json'};

/// [ApiAuthRepository] against a fake API that records each request as "METHOD /path body".
Future<(ApiAuthRepository, List<String>)> _repo(http.Response Function(http.Request req) answer) async {
  final calls = <String>[];
  final client = MockClient((req) async {
    calls.add('${req.method} ${req.url.path}${req.body.isEmpty ? '' : ' ${req.body}'}');
    return answer(req);
  });
  SharedPreferences.setMockInitialValues({});
  return (ApiAuthRepository(ApiClient(baseUrl: 'http://api.test/v1', session: await ApiSession.load(), client: client)), calls);
}

void main() {
  test('signing in says it is the passenger app', () async {
    final (repo, calls) = await _repo((_) => http.Response('{"accessToken":"t1","isNewUser":false}', 200, headers: _json));
    expect(await repo.verifyOtp('98430 12345', '123456'), OtpResult.existingUser);
    final body = jsonDecode(calls.single.substring(calls.single.indexOf('{'))) as Map;
    expect(body, {'phone': '+919843012345', 'code': '123456', 'app': 'passenger'});
  });
}
