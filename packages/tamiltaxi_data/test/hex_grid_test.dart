import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';

void main() {
  const centre = LatLng(11.0168, 76.9658);
  const distance = Distance(roundResult: false);

  test('a k-step disk has 1, 7, 19, 37 cells', () {
    expect([for (var k = 0; k < 4; k++) hexDiskCoords(k).length], [1, 7, 19, 37]);
  });

  test('a hexagon has six corners at the edge length from its centre, one pointing north', () {
    final h = hexagonAround(centre, HexRes.r8);
    expect(h, hasLength(6));
    for (final p in h) {
      expect(distance(centre, p), closeTo(HexRes.r8, 2));
    }
    expect(h.first.latitude, greaterThan(centre.latitude));
    expect(h.first.longitude, closeTo(centre.longitude, 1e-9));
    // Regular: every side is as long as the edge.
    for (var i = 0; i < 6; i++) {
      expect(distance(h[i], h[(i + 1) % 6]), closeTo(HexRes.r8, 2));
    }
  });

  test('neighbouring cells share corners, so the cells tile the area', () {
    final cells = hexDiskCells(centre, HexRes.r8, 1);
    final middle = cells.first;
    for (final other in cells.skip(1)) {
      final shared = middle.where((a) => other.any((b) => distance(a, b) < 1)).length;
      expect(shared, 2, reason: 'each ring-1 cell touches the centre cell along one edge');
    }
  });

  test('the disk outline is one closed ring of 6 · (2k + 1) points', () {
    for (var k = 0; k < 4; k++) {
      expect(hexDiskOutline(centre, HexRes.r7, k), hasLength(6 * (2 * k + 1)));
    }
  });

  test('hexRingsFor covers the radius', () {
    final k = hexRingsFor(18000, HexRes.r7);
    final outline = hexDiskOutline(centre, HexRes.r7, k);
    final nearest = outline.map((p) => distance(centre, p)).reduce((a, b) => a < b ? a : b);
    expect(nearest, greaterThanOrEqualTo(18000 * 0.9));
  });

  test('the demo demand map is hexes: res-7 hotspots with seven res-8 children and a service-area outline', () {
    final map = DemandMap.demo();
    expect(map.hotspots, hasLength(Seed.demandZones.length));
    expect(map.hotspots.first.level, HotspotLevel.high);
    for (final h in map.hotspots) {
      expect(h.boundary, hasLength(6));
      expect(h.nested, hasLength(7));
    }
    expect(map.serviceArea, hasLength(1));
    expect(DemandMap.demo(quiet: true).hotspots.every((h) => h.level == HotspotLevel.busy), isTrue);
  });
}
