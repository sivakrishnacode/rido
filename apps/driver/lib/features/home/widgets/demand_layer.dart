import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart' show Marker;
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

/// Zoom levels for the layers: the service area when zoomed out, demand hexes in the city view, their nested hexes
/// once zoomed in far enough to tell streets apart (like H3's hex-in-hex grid).
const double kServiceAreaMaxZoom = 12.8;
const double kHotspotMinZoom = 10.5;
const double kNestedMinZoom = 13.2;

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
        fillColor: RidoColors.navy900.withValues(alpha: 0.04),
        strokeColor: RidoColors.navy900.withValues(alpha: 0.7),
        strokeWidth: 2.5,
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

/// "High demand" (or the surge, e.g. "1.2x") on the hottest hexes.
List<Marker> demandLabels(DemandMap? map) {
  if (map == null) return const [];
  return [
    for (final h in map.hotspots.where((h) => h.level == HotspotLevel.high).take(4))
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
