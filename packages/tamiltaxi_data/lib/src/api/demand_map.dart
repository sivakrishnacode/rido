import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../geo/hex_grid.dart';
import '../seed.dart';

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
    this.name,
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

  /// Where most of its pickups are ("Gandhipuram"); null before the area has trips.
  final String? name;

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
            name: (h['name'] as String?)?.trim().isEmpty ?? true ? null : (h['name'] as String).trim(),
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

  /// Mock mode and the Design gallery: what `/demand/hotspots` returns, without the API. Each seeded busy area is
  /// a res-7-sized hex with its seven res-8-sized children, and the service area is a hex outline. [quiet] (S-12):
  /// busy, nothing "high".
  factory DemandMap.demo({bool quiet = false}) {
    const levels = [HotspotLevel.high, HotspotLevel.busy, HotspotLevel.some];
    const childScores = [1.0, 0.7, 0.45, 0.3, 0.2, 0.55, 0.15];
    return DemandMap(
      at: DateTime.now(),
      hotspots: [
        for (final (i, z) in Seed.demandZones.indexed)
          Hotspot(
            cell: 'demo-${z.name}',
            level: quiet ? HotspotLevel.busy : levels[i % levels.length],
            score: 1 - i * 0.3,
            multiplier: 1,
            centre: z.centre,
            name: z.name,
            boundary: hexagonAround(z.centre, HexRes.r7),
            nested: [
              for (final (j, c) in hexDisk(z.centre, HexRes.r8, 1, rotation: HexRes.childRotation).indexed)
                NestedHex(
                  cell: 'demo-${z.name}-$j',
                  score: childScores[j],
                  boundary: hexagonAround(c, HexRes.r8, rotation: HexRes.childRotation),
                ),
            ],
          ),
      ],
      serviceArea: [
        hexDiskOutline(Seed.cityCentre, HexRes.r7, hexRingsFor(Seed.serviceRadiusKm * 1000, HexRes.r7)),
      ],
    );
  }
}
