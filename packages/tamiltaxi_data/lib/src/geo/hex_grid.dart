import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// Hexagons the size of H3 cells, for the demo map (mock mode, Design gallery) and for map decorations, so no
/// map ever shows a circle with a radius: the service works on H3 hexes (res 8 for service areas and the driver
/// index, res 7 for demand and surge). Live maps draw the real H3 outlines the API sends (`/demand/hotspots`);
/// these are look-alikes laid out on a local flat grid (fine at city scale).
///
/// Pointy-top hexagons: a corner points north. [rotation] turns a grid clockwise, in degrees.
abstract final class HexRes {
  /// H3 average edge length per resolution, in metres.
  static const double r7 = 1406.48;
  static const double r8 = 531.41;
  static const double r9 = 200.79;

  /// H3 is aperture 7: a child grid has edge / √7 and is turned by this much against its parent.
  static const double childRotation = 19.1066;
}

final double _sqrt3 = math.sqrt(3);

/// Axial grid coordinates of the cells within [k] steps of the centre cell (k = 0: 1 cell, 1: 7, 2: 19…), the
/// centre cell first, then ring by ring.
List<(int, int)> hexDiskCoords(int k) => [
      for (var q = -k; q <= k; q++)
        for (var r = math.max(-k, -q - k); r <= math.min(k, -q + k); r++) (q, r),
    ]..sort((a, b) => _ring(a).compareTo(_ring(b)));

int _ring((int, int) c) => math.max(c.$1.abs(), math.max(c.$2.abs(), (c.$1 + c.$2).abs()));

/// The six corners of the hexagon with edge [edgeM] around [centre].
List<LatLng> hexagonAround(LatLng centre, double edgeM, {double rotation = 0}) => [
      for (var i = 0; i < 6; i++) _offset(centre, _polar(edgeM, 90 - 60.0 * i), rotation),
    ];

/// Centres of the cells within [k] steps of the cell centred on [centre].
List<LatLng> hexDisk(LatLng centre, double edgeM, int k, {double rotation = 0}) => [
      for (final (q, r) in hexDiskCoords(k)) _offset(centre, _axialToXY(q, r, edgeM), rotation),
    ];

/// The cells within [k] steps of [centre] as hexagons (their edges meet, so they tile the area).
List<List<LatLng>> hexDiskCells(LatLng centre, double edgeM, int k, {double rotation = 0}) => [
      for (final c in hexDisk(centre, edgeM, k, rotation: rotation)) hexagonAround(c, edgeM, rotation: rotation),
    ];

/// The outer edge of the [k]-step disk around [centre]: one ring of points, the jagged hex outline an H3 area has.
List<LatLng> hexDiskOutline(LatLng centre, double edgeM, int k, {double rotation = 0}) {
  final cells = hexDiskCoords(k).toSet();
  // Neighbour in direction d (0 = east, then every 60° anticlockwise) and the corners of the edge facing it.
  const dirs = [(1, 0), (1, -1), (0, -1), (-1, 0), (-1, 1), (0, 1)];
  final next = <(int, int), (int, int)>{};
  final points = <(int, int), (double, double)>{};
  (int, int) key((double, double) p) => ((p.$1 * 1000).round(), (p.$2 * 1000).round());
  for (final (q, r) in cells) {
    final (cx, cy) = _axialToXY(q, r, edgeM);
    for (var d = 0; d < 6; d++) {
      final (dq, dr) = dirs[d];
      if (cells.contains((q + dq, r + dr))) continue;
      // The edge facing direction 60·d runs between the corners at 60·d − 30° and 60·d + 30° (anticlockwise).
      final (ax, ay) = _polar(edgeM, 60.0 * d - 30);
      final (bx, by) = _polar(edgeM, 60.0 * d + 30);
      final a = (cx + ax, cy + ay);
      final b = (cx + bx, cy + by);
      next[key(a)] = key(b);
      points[key(a)] = a;
    }
  }
  if (next.isEmpty) return const [];
  final start = next.keys.first;
  final ring = <LatLng>[];
  var at = start;
  do {
    ring.add(_offset(centre, points[at]!, rotation));
    at = next[at]!;
  } while (at != start && ring.length <= next.length);
  return ring;
}

/// The smallest k whose disk of cells with edge [edgeM] reaches [radiusM] from the centre.
int hexRingsFor(double radiusM, double edgeM) => (radiusM / (_sqrt3 * edgeM)).ceil();

/// Planar (east, north) metres of axial cell (q, r) for pointy-top cells with edge [edgeM].
(double, double) _axialToXY(int q, int r, double edgeM) => (edgeM * _sqrt3 * (q + r / 2), -edgeM * 1.5 * r);

(double, double) _polar(double m, double deg) {
  final a = deg * math.pi / 180;
  return (m * math.cos(a), m * math.sin(a));
}

/// [centre] moved by planar (east, north) metres, after turning the vector clockwise by [rotation] degrees.
LatLng _offset(LatLng centre, (double, double) xy, double rotation) {
  final a = -rotation * math.pi / 180;
  final (x, y) = xy;
  final e = x * math.cos(a) - y * math.sin(a);
  final n = x * math.sin(a) + y * math.cos(a);
  // Metres per degree on the WGS84 ellipsoid at this latitude.
  final phi = centre.latitude * math.pi / 180;
  final mLat = 111132.92 - 559.82 * math.cos(2 * phi) + 1.175 * math.cos(4 * phi);
  final mLng = 111412.84 * math.cos(phi) - 93.5 * math.cos(3 * phi);
  return LatLng(centre.latitude + n / mLat, centre.longitude + e / mLng);
}
