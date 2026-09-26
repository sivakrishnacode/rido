import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

/// How busy a demand hex is right now (`GET /v1/demand/hotspots`).
enum HotspotLevel { high, busy, some }

/// A res-8 hex (≈0.7 km²) inside a hotspot; [score] 0–1 relative to the busiest one in the same hotspot.
@immutable
class NestedHex {
  const NestedHex({required this.cell, required this.score, required this.boundary});
  final String cell;
  final double score;
  final List<LatLng> boundary;
}

/// A res-7 demand hex (≈5 km²) with its busy nested hexes.
@immutable
class Hotspot {
  const Hotspot({
    required this.cell,
    required this.level,
    required this.score,
    required this.multiplier,
    required this.centre,
    required this.boundary,
    this.nested = const [],
  });

  final String cell;
  final HotspotLevel level;

  /// 0–1, relative to the busiest hotspot shown.
  final double score;

  /// Live surge on this hex (1 = none).
  final double multiplier;
  final LatLng centre;
  final List<LatLng> boundary;
  final List<NestedHex> nested;

  bool get isSurging => multiplier > 1.001;
}

/// The driver's demand map: hotspots and the service-area outline.
@immutable
class DemandMap {
  const DemandMap({required this.at, this.hotspots = const [], this.serviceArea = const []});
  final DateTime at;
  final List<Hotspot> hotspots;
  final List<List<LatLng>> serviceArea;

  factory DemandMap.fromJson(Map<String, dynamic> j) {
    List<LatLng> ring(Object? raw) => [
          for (final p in (raw as List? ?? const []))
            LatLng(((p as List)[0] as num).toDouble(), (p[1] as num).toDouble()),
        ];
    return DemandMap(
      at: DateTime.tryParse('${j['at']}') ?? DateTime.now(),
      hotspots: [
        for (final h in (j['hotspots'] as List? ?? const []))
          Hotspot(
            cell: '${(h as Map)['cell']}',
            level: HotspotLevel.values.firstWhere((l) => l.name == h['level'], orElse: () => HotspotLevel.some),
            score: (h['score'] as num?)?.toDouble() ?? 0,
            multiplier: (h['multiplier'] as num?)?.toDouble() ?? 1,
            centre: ring([h['centre']]).first,
            boundary: ring(h['boundary']),
            nested: [
              for (final n in (h['nested'] as List? ?? const []))
                NestedHex(cell: '${(n as Map)['cell']}', score: (n['score'] as num?)?.toDouble() ?? 0, boundary: ring(n['boundary'])),
            ],
          ),
      ],
      serviceArea: [for (final r in (j['serviceArea'] as List? ?? const [])) ring(r)],
    );
  }
}
