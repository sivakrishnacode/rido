import 'package:flutter_test/flutter_test.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_driver/features/home/widgets/demand_layer.dart';

const _ring = [LatLng(11, 76.9), LatLng(11.1, 76.9), LatLng(11.1, 77)];

DemandMap _map() => DemandMap(
      at: DateTime(2026, 9, 26),
      serviceArea: const [_ring],
      hotspots: const [
        Hotspot(
          cell: 'a',
          level: HotspotLevel.high,
          score: 1,
          multiplier: 1.2,
          centre: LatLng(11.05, 76.95),
          boundary: _ring,
          nested: [NestedHex(cell: 'a1', score: 1, boundary: _ring), NestedHex(cell: 'a2', score: 0.2, boundary: _ring)],
        ),
        Hotspot(cell: 'b', level: HotspotLevel.some, score: 0.2, multiplier: 1, centre: LatLng(11, 77), boundary: _ring),
      ],
    );

void main() {
  test('zoomed out: only the service area; city zoom: demand hexes; zoomed in: nested hexes too', () {
    final polys = demandPolygons(_map());
    int visibleAt(double z) => polys.where((p) => p.visibleAt(z)).length;
    expect(visibleAt(10), 1, reason: 'service area only');
    expect(visibleAt(12), 3, reason: 'service area + 2 demand hexes');
    expect(visibleAt(14.6), 4, reason: '2 demand hexes + 2 nested hexes (Home default zoom)');
  });

  test('busier nested hexes are shaded darker', () {
    final nested = demandPolygons(_map()).where((p) => p.zIndex == 2).toList();
    expect(nested.first.fillColor.a, greaterThan(nested.last.fillColor.a));
  });

  test('labels only on high-demand hexes, with the surge', () {
    final labels = demandLabels(_map());
    expect(labels, hasLength(1));
    expect(labels.single.point, const LatLng(11.05, 76.95));
  });

  test('no data yet: nothing drawn', () {
    expect(demandPolygons(null), isEmpty);
    expect(demandLabels(null), isEmpty);
  });
}
