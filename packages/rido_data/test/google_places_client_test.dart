import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:rido_data/rido_data.dart';

const _autocomplete = '''
{
  "suggestions": [
    {
      "placePrediction": {
        "place": "places/ChIJbrooke",
        "placeId": "ChIJbrooke",
        "text": {"text": "Brookefields Mall, Krishnasamy Road, RS Puram, Coimbatore, Tamil Nadu, India"},
        "structuredFormat": {
          "mainText": {"text": "Brookefields Mall"},
          "secondaryText": {"text": "Krishnasamy Road, RS Puram, Coimbatore, Tamil Nadu, India"}
        }
      }
    },
    {
      "placePrediction": {
        "placeId": "ChIJnoStructured",
        "text": {"text": "Gandhipuram Bus Stand, Gandhipuram, Coimbatore"}
      }
    },
    {"queryPrediction": {"text": {"text": "brook"}}}
  ]
}
''';

const _details = '''
{
  "id": "ChIJbrooke",
  "formattedAddress": "Brookefields Mall, 73, Krishnasamy Rd, RS Puram, Coimbatore, Tamil Nadu 641001, India",
  "location": {"latitude": 11.0089, "longitude": 76.9604},
  "displayName": {"text": "Brookefields Mall", "languageCode": "en"}
}
''';

const _geocode = '''
{
  "status": "OK",
  "results": [
    {
      "types": ["plus_code"],
      "formatted_address": "2XJ8+4V Coimbatore, Tamil Nadu, India"
    },
    {
      "types": ["route"],
      "formatted_address": "Cross Cut Rd, Gandhipuram, Coimbatore, Tamil Nadu 641012, India",
      "address_components": [
        {"long_name": "Cross Cut Road", "short_name": "Cross Cut Rd", "types": ["route"]},
        {"long_name": "Gandhipuram", "short_name": "Gandhipuram", "types": ["sublocality_level_1", "sublocality"]}
      ]
    }
  ]
}
''';

void main() {
  test('autocomplete suggestions become g: places with a placeholder location', () {
    final places = GooglePlacesClient.parseAutocomplete(jsonDecode(_autocomplete));
    expect(places, hasLength(2));
    expect(places[0].id, 'g:ChIJbrooke');
    expect(places[0].name, 'Brookefields Mall');
    expect(places[0].address, 'Krishnasamy Road, RS Puram, Coimbatore');
    expect(places[0].location, GooglePlacesClient.biasCentre);
    expect(places[1].name, 'Gandhipuram Bus Stand');
    expect(places[1].address, 'Gandhipuram, Coimbatore');
    expect(GooglePlacesClient.parseAutocomplete(const {}), isEmpty);
  });

  test('place details give coordinates and a short address', () {
    final p = GooglePlacesClient.parsePlaceDetails(jsonDecode(_details))!;
    expect(p.id, 'g:ChIJbrooke');
    expect(p.name, 'Brookefields Mall');
    expect(p.address, '73, Krishnasamy Rd, RS Puram, Coimbatore');
    expect(p.location.latitude, closeTo(11.0089, 1e-9));
    expect(p.location.longitude, closeTo(76.9604, 1e-9));
    expect(GooglePlacesClient.parsePlaceDetails({'id': 'x'}), isNull);
  });

  test('reverse geocode skips plus codes and names the road', () {
    const pin = LatLng(11.0175, 76.9674);
    final p = GooglePlacesClient.parseGeocode(jsonDecode(_geocode), pin)!;
    expect(p.name, 'Cross Cut Road');
    expect(p.address, 'Cross Cut Rd, Gandhipuram, Coimbatore');
    expect(p.location, pin);
    expect(GooglePlacesClient.parseGeocode({'status': 'ZERO_RESULTS', 'results': []}, pin), isNull);
  });

  test('one session token per search session, new one after details', () {
    final client = GooglePlacesClient(apiKey: 'test', random: math.Random(1));
    final t1 = client.sessionToken;
    expect(client.sessionToken, t1);
    expect(t1, matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
    client.endSession();
    expect(client.sessionToken, isNot(t1));
  });

  test('short queries never reach the network', () async {
    final client = GooglePlacesClient(apiKey: 'test');
    expect(await client.autocomplete('br'), isEmpty);
  });

  test('seed places resolve to themselves without a key', () async {
    final repo = MockPlacesRepository(MockDatabase(), () => const DemoSettings());
    expect(await repo.resolve(Seed.brookefields), same(Seed.brookefields));
    await expectLater(
      repo.resolve(const Place(id: 'g:abc', name: 'X', address: 'Y', location: GooglePlacesClient.biasCentre)),
      throwsA(isA<OfflineException>()),
    );
  });
}
