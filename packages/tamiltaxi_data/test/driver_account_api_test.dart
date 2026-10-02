import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';

void main() {
  test('a rejected emergency contact keeps the old one (added first, old removed after)', () async {
    final calls = <String>[];
    var rejectPost = true;
    final client = MockClient((req) async {
      calls.add('${req.method} ${req.url.path}');
      if (req.method == 'GET') {
        return http.Response('{"emergencyContacts":[{"id":"c1","name":"Anbu","relation":"Brother","phone":"+919843012345"}]}', 200,
            headers: {'content-type': 'application/json'});
      }
      if (req.method == 'POST' && rejectPost) {
        return http.Response('{"message":"Enter a valid 10-digit Indian mobile number"}', 400,
            headers: {'content-type': 'application/json'});
      }
      return http.Response('{}', req.method == 'DELETE' ? 204 : 201, headers: {'content-type': 'application/json'});
    });
    SharedPreferences.setMockInitialValues({});
    final api = ApiClient(baseUrl: 'http://api.test/v1', session: await ApiSession.load(), client: client);
    final repo = ApiDriverRepository(api);
    const next = EmergencyContact(id: 'c1', name: 'Anbu', relation: 'Brother', phone: '1234567890');

    await expectLater(repo.updateEmergencyContact(next), throwsA(isA<ApiException>()));
    expect(calls, ['GET /v1/me', 'POST /v1/me/emergency-contacts']);

    calls.clear();
    rejectPost = false;
    await repo.updateEmergencyContact(next.copyWith(phone: '9843012399'));
    expect(calls, ['GET /v1/me', 'POST /v1/me/emergency-contacts', 'DELETE /v1/me/emergency-contacts/c1']);
  });

  test('the driver app signs in with app "driver"', () async {
    Map<String, dynamic>? body;
    final client = MockClient((req) async {
      body = jsonDecode(req.body) as Map<String, dynamic>;
      return http.Response('{"accessToken":"t1","driverId":"d1","isNewUser":false}', 200,
          headers: {'content-type': 'application/json'});
    });
    SharedPreferences.setMockInitialValues({});
    final api = ApiClient(baseUrl: 'http://api.test/v1', session: await ApiSession.load(), client: client);
    expect(await ApiDriverRepository(api).verifyOtp('98430 12345', '123456'), OtpResult.existingUser);
    expect(body, {'phone': '+919843012345', 'code': '123456', 'app': 'driver'});
    expect(api.session.driverId, 'd1');
  });

  test('sign-up sent again after a lost answer (200, the same driver) still stores the session', () async {
    final client = MockClient((req) async {
      if (req.method == 'POST' && req.url.path == '/v1/drivers') {
        return http.Response('{"driver":{"id":"d9"},"accessToken":"fresh"}', 200, headers: {'content-type': 'application/json'});
      }
      return http.Response('{"id":"d9","user":{"name":"Anbu"},"vehicleKind":"BIKE","plate":"TN 37 AB 4521"}', 200,
          headers: {'content-type': 'application/json'});
    });
    SharedPreferences.setMockInitialValues({'tamiltaxi.accessToken': 'phone-only'});
    final api = ApiClient(baseUrl: 'http://api.test/v1', session: await ApiSession.load(), client: client);
    final repo = ApiDriverRepository(api);
    expect(repo.isLoggedIn, isFalse);
    final driver = await repo.register(
      const DriverProfile(
          id: '', name: 'Anbu', phone: '+919843012345', vehicleKind: VehicleKind.bike, vehicleModel: 'Splendor',
          vehicleColor: 'Black', plate: 'TN 37 AB 4521', rating: 5, rides: 0, upiId: 'anbu@okaxis'),
      WorkType.rides,
    );
    expect(driver.id, 'd9');
    expect(api.session.token, 'fresh');
    expect(repo.isLoggedIn, isTrue);
  });
}
