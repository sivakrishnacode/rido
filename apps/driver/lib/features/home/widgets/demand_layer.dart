import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart' show Marker;
import 'package:latlong2/latlong.dart' show Distance, LengthUnit;
import 'package:tamiltaxi_data/tamiltaxi_data.dart';
import 'package:tamiltaxi_ui/tamiltaxi_ui.dart';

/// Zoom levels for the layers: the service area when zoomed out, demand hexes in the city view, their nested hexes
/// once zoomed in far enough to tell streets apart (like H3's hex-in-hex grid).
const double kServiceAreaMaxZoom = 12.8;
const double kHotspotMinZoom = 10.5;
const double kNestedMinZoom = 13.2;

/// "High demand" labels only from street level: zoomed out to the whole city they pile up on each other.
const double kLabelMinZoom = 12.5;

/// Room one label needs on screen (logical px); a label closer than this to a shown one is left out.
const Size _labelBox = Size(180, 44);

const _high = Color(0xFFE64A19); // coral-deep
const _busy = Color(0xFFF59E0B); // amber
const _some = Color(0xFFFBBF24); // yellow

Color _levelColor(HotspotLevel level) => switch (level) {
      HotspotLevel.high => _high,
      HotspotLevel.busy => _busy,
      HotspotLevel.some => _some,
    };

/// Polygons for [map]: the service-area edge, each demand hex filled by its level, and inside it the busy nested
/// hexes shaded by their own share of pickups.
List<MapPolygon> demandPolygons(DemandMap? map) {
  if (map == null) return const [];
  return [
    for (final ring in map.serviceArea)
      MapPolygon(
        points: ring,
        fillColor: TtColors.navy900.withValues(alpha: 0.04),
        strokeColor: TtColors.navy900.withValues(alpha: 0.4),
        strokeWidth: 1,
        maxZoom: kServiceAreaMaxZoom,
      ),
    for (final h in map.hotspots) ...[
      MapPolygon(
        points: h.boundary,
        fillColor: _levelColor(h.level).withValues(alpha: h.level == HotspotLevel.high ? 0.22 : 0.14),
        strokeColor: _levelColor(h.level).withValues(alpha: 0.85),
        strokeWidth: 2,
        zIndex: 1,
        minZoom: kHotspotMinZoom,
      ),
      for (final n in h.nested)
        MapPolygon(
          points: n.boundary,
          fillColor: _levelColor(h.level).withValues(alpha: 0.08 + 0.34 * n.score),
          strokeColor: _levelColor(h.level).withValues(alpha: 0.45),
          strokeWidth: 1,
          zIndex: 2,
          minZoom: kNestedMinZoom,
        ),
    ],
  ];
}

/// "High demand" (or the surge, e.g. "1.2x") on the hottest hexes at [zoom] (the map camera's): none below
/// [kLabelMinZoom], and a label that would overlap one already placed is dropped (hottest first, surge first).
List<Marker> demandLabels(DemandMap? map, {double zoom = 14.6}) {
  if (map == null || zoom < kLabelMinZoom) return const [];
  final hot = map.hotspots.where((h) => h.level == HotspotLevel.high).toList()
    ..sort((a, b) => b.multiplier.compareTo(a.multiplier));
  final placed = <Offset>[];
  for (final h in hot) {
    if (placed.length == 4) break;
    final p = _world(h.centre, zoom);
    final clear = placed.every((q) => (p.dx - q.dx).abs() >= _labelBox.width || (p.dy - q.dy).abs() >= _labelBox.height);
    if (clear) placed.add(p);
  }
  return [
    for (final h in hot)
      if (placed.contains(_world(h.centre, zoom)))
        Marker(
        point: h.centre,
        width: 200,
        height: 40,
        child: Center(
          child: DemandLabel(text: h.isSurging ? 'High demand · ${h.multiplier.toStringAsFixed(1)}x' : 'High demand'),
        ),
      ),
  ];
}

/// Web-Mercator position in logical px (256 px world at zoom 0, as Google and flutter_map use).
Offset _world(LatLng p, double zoom) {
  final scale = 256 * math.pow(2, zoom).toDouble();
  final s = math.sin(p.latitude * math.pi / 180);
  return Offset((p.longitude + 180) / 360 * scale, (0.5 - math.log((1 + s) / (1 - s)) / (4 * math.pi)) * scale);
}

/// The hotspot worth driving to from [from]: the nearest "high" one, else the nearest "busy" one; null without a
/// map, a position or any busy area. Quiet ("some") hexes are never suggested.
({Hotspot hotspot, double km})? nearestHotspot(DemandMap? map, LatLng? from) {
  if (map == null || from == null) return null;
  const distance = Distance();
  for (final level in const [HotspotLevel.high, HotspotLevel.busy]) {
    ({Hotspot hotspot, double km})? best;
    for (final h in map.hotspots.where((h) => h.level == level)) {
      final km = distance.as(LengthUnit.Meter, from, h.centre) / 1000;
      if (best == null || km < best.km) best = (hotspot: h, km: km);
    }
    if (best != null) return best;
  }
  return null;
}
