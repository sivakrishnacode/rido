import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';
import 'package:tamiltaxi_data/src/api/api_mappers.dart' show savedPlaceToJson;

const _json = {'content-type': 'application/json'};

void main() {
  const pinned = SavedPlace(
    id: 'p1',
    label: 'Home',
    kind: SavedPlaceKind.home,
    place: Place(id: 'pin-1', name: 'Pinned location', address: '', location: LatLng(11.01, 76.95)),
  );

  test('a pinned spot is saved with an address; long fields fit the API', () {
    expect(savedPlaceToJson(pinned)['address'], 'Pinned location');
    final long = savedPlaceToJson(SavedPlace(
      id: 'p2',
      label: 'L' * 50,
      kind: SavedPlaceKind.other,
      place: Place(id: 'x', name: 'N' * 130, address: 'A' * 210, location: const LatLng(11, 77)),
    ));
    expect((long['label']! as String).length, 40);
    expect((long['name']! as String).length, 120);
    expect((long['address']! as String).length, 200);
  });

  test('editing a place adds the new one before removing the old, so a rejected edit keeps it', () async {
    final calls = <String>[];
    final client = MockClient((req) async {
      calls.add('${req.method} ${req.url.path}');
      if (req.method == 'GET') {
        return http.Response(
            '{"savedPlaces":[{"id":"p1","label":"Home","kind":"home","name":"Old home","address":"Gandhipuram","lat":11,"lng":77}]}',
            200,
            headers: _json);
      }
      if (req.method == 'POST') return http.Response('{"message":"address must be longer"}', 400, headers: _json);
      return http.Response('', 204);
    });
    SharedPreferences.setMockInitialValues({});
    final repo = ApiPlacesRepository(ApiClient(baseUrl: 'http://api.test/v1', session: await ApiSession.load(), client: client));
    await expectLater(repo.saveSavedPlace(pinned), throwsA(isA<ApiException>()));
    expect(calls, ['GET /v1/me', 'POST /v1/me/saved-places']);
  });
}
