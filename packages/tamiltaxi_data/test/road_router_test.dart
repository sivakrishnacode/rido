import 'package:flutter_test/flutter_test.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';

void main() {
  tearDown(() => RoadRouter.backend = null);

  test('live: no route from the server draws the curved line, never the public OSRM server', () async {
    final osrmCalls = <String>[];
    final original = RoadRouter.osrm;
    RoadRouter.osrm = (a, b) async {
      osrmCalls.add('$a>$b');
      return [a, b];
    };
    addTearDown(() => RoadRouter.osrm = original);

    // The server only has an estimate (non-Google source → null), then fails outright.
    RoadRouter.backend = (from, to, mode) async => null;
    expect(await RoadRouter.fetch(const LatLng(11.01, 76.95), const LatLng(11.02, 76.96)), isNull);
    RoadRouter.backend = (from, to, mode) async => throw const OfflineException();
    expect(await RoadRouter.fetch(const LatLng(11.03, 76.95), const LatLng(11.04, 76.96)), isNull);
    expect(osrmCalls, isEmpty);

    // The seed-data demo (no backend) still uses it.
    RoadRouter.backend = null;
    expect(await RoadRouter.fetch(const LatLng(11.05, 76.95), const LatLng(11.06, 76.96)), hasLength(2));
    expect(osrmCalls, hasLength(1));
  });
}
