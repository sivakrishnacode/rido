import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';
import 'package:tamiltaxi_data/src/api/api_mappers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'profile preferences preserve a nameless account and can clear email',
    () async {
      SharedPreferences.setMockInitialValues({});
      Map<String, dynamic>? patch;
      final api = ApiClient(
        baseUrl: 'http://api.test/v1',
        session: await ApiSession.load(),
        client: MockClient((r) async {
          if (r.method == 'PATCH') {
            patch = jsonDecode(r.body) as Map<String, dynamic>;
          }
          return http.Response(
            jsonEncode({
              'name': '',
              'phone': '+919843012345',
              'email': 'old@example.com',
              'emergencyContacts': [],
              'savedPlaces': [],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      await ApiAuthRepository(api).updateProfile(
        const PassengerProfile(
          name: 'Rider',
          phone: '+919843012345',
          gender: Gender.preferNotToSay,
        ),
      );
      expect(patch!.containsKey('name'), isFalse);
      expect(patch!['email'], isNull);
    },
  );
  test('saved landmark note survives JSON and edits to other fields', () {
    final saved = savedPlaceFromJson({
      'id': 's1',
      'label': 'Home',
      'kind': 'home',
      'name': 'Street',
      'address': 'Address',
      'lat': 11.0,
      'lng': 77.0,
      'note': 'Gate 2, second floor',
    });
    expect(
      savedPlaceToJson(saved.copyWith(label: 'My home'))['note'],
      'Gate 2, second floor',
    );
    expect(savedPlaceToJson(saved.copyWith(note: ''))['note'], '');
  });
  test(
    'driver status cache is removed together with the signed-in account',
    () async {
      SharedPreferences.setMockInitialValues({});
      final session = await ApiSession.load();
      await session.saveDriverStatus('APPROVED');
      expect(session.lastDriverStatus, 'APPROVED');
      await session.clear();
      expect(session.lastDriverStatus, isNull);
    },
  );
  test(
    'ticket screenshot uses the created ticket and the multipart file field',
    () async {
      SharedPreferences.setMockInitialValues({});
      late http.Request received;
      final api = ApiClient(
        baseUrl: 'http://api.test/v1',
        session: await ApiSession.load(),
        client: MockClient((r) async {
          received = r;
          return http.Response(
            '{}',
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      await ApiSupportRepository(
        api,
      ).uploadAttachment('ticket1', [1, 2, 3], 'shot.jpg');
      expect(received.url.path, '/v1/tickets/ticket1/attachment');
      expect(received.method, 'POST');
      expect(received.body, contains('name="file"; filename="shot.jpg"'));
    },
  );
  test(
    'missing payment period does not break history; update dates are real',
    () {
      expect(
        paymentFromJson({
          'subscription': {
            'plan': {'period': ''},
          },
        }).label,
        'Plan payment',
      );
      final ticket = ticketFromJson({
        'id': 't1',
        'createdAt': '2026-10-01T10:00:00Z',
        'updatedAt': '2026-10-03T10:00:00Z',
      });
      expect(ticket.updatedAt!.isAfter(ticket.createdAt), isTrue);
    },
  );
}
