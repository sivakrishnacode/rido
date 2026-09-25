import 'package:flutter_test/flutter_test.dart';
import 'package:rido_data/rido_data.dart';

void main() {
  test('decodes the example from Google\'s polyline algorithm docs', () {
    final pts = decodePolyline('_p~iF~ps|U_ulLnnqC_mqNvxq`@');
    expect(pts, hasLength(3));
    expect(pts[0].latitude, closeTo(38.5, 1e-9));
    expect(pts[0].longitude, closeTo(-120.2, 1e-9));
    expect(pts[1].latitude, closeTo(40.7, 1e-9));
    expect(pts[1].longitude, closeTo(-120.95, 1e-9));
    expect(pts[2].latitude, closeTo(43.252, 1e-9));
    expect(pts[2].longitude, closeTo(-126.453, 1e-9));
  });

  test('empty string gives no points; truncated input throws', () {
    expect(decodePolyline(''), isEmpty);
    expect(() => decodePolyline('_p~iF~ps|'), throwsFormatException);
  });

  test('parses a computeRoutes response', () {
    final json = {
      'routes': [
        {
          'distanceMeters': 5210,
          'duration': '812s',
          'polyline': {'encodedPolyline': '_p~iF~ps|U_ulLnnqC_mqNvxq`@'},
        },
      ],
    };
    final route = RoadRouter.parseGoogleRoute(json);
    expect(route, hasLength(3));
    expect(RoadRouter.parseGoogleRoute({'routes': []}), isNull);
    expect(RoadRouter.parseGoogleRoute(const {}), isNull);
  });
}
