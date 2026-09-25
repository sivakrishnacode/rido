import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:latlong2/latlong.dart';

import '../seed.dart';
import 'trip_simulator.dart';

/// Road-following routes from the free public OSRM router (no key), cached in memory.
///
/// [roadPath] is synchronous: it returns the cached road route if we have one, otherwise the
/// curved stand-in from [curvedPath] and starts fetching the real route in the background.
/// Offline (or in tests, where [enabled] is false) the curved line is used.
abstract final class RoadRouter {
  static bool enabled = true;
  static const _base = 'https://router.project-osrm.org/route/v1/driving';

  static final Map<String, List<LatLng>> _cache = {};
  static final Map<String, Future<List<LatLng>?>> _inFlight = {};

  static String _key(LatLng a, LatLng b) =>
      '${a.latitude.toStringAsFixed(5)},${a.longitude.toStringAsFixed(5)}|'
      '${b.latitude.toStringAsFixed(5)},${b.longitude.toStringAsFixed(5)}';

  /// Cached road route, if already fetched.
  static List<LatLng>? cached(LatLng a, LatLng b) => _cache[_key(a, b)];

  /// Fetches (once) and caches the road route; null if routing is unavailable.
  static Future<List<LatLng>?> fetch(LatLng a, LatLng b) {
    final key = _key(a, b);
    final hit = _cache[key];
    if (hit != null) return Future.value(hit);
    if (!enabled) return Future.value(null);
    return _inFlight[key] ??= _get(a, b).then((p) {
      _inFlight.remove(key);
      if (p != null) _cache[key] = p;
      return p;
    });
  }

  static Future<List<LatLng>?> _get(LatLng a, LatLng b) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final uri = Uri.parse('$_base/${a.longitude},${a.latitude};${b.longitude},${b.latitude}'
          '?overview=full&geometries=geojson');
      final req = await client.getUrl(uri).timeout(const Duration(seconds: 6));
      req.headers.set(HttpHeaders.userAgentHeader, 'RidoApp/0.1 (prototype)');
      final res = await req.close().timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return null;
      final body = await res.transform(utf8.decoder).join().timeout(const Duration(seconds: 6));
      final coords = (((jsonDecode(body) as Map)['routes'] as List).first as Map)['geometry']['coordinates'] as List;
      final pts = [for (final c in coords) LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble())];
      return pts.length >= 2 ? pts : null;
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  /// Warms the cache with every route the demo flows draw.
  static Future<void> prefetchDemoRoutes() async {
    final pairs = <(LatLng, LatLng)>[
      (Seed.gandhipuram.location, Seed.brookefields.location),
      (offsetPoint(Seed.gandhipuram.location, 900, 35), Seed.gandhipuram.location),
      (Seed.peelamedu.location, Seed.raceCourse.location),
      (offsetPoint(Seed.peelamedu.location, 1100, 210), Seed.peelamedu.location),
      (Seed.driverHome, Seed.gandhipuram.location),
      (Seed.driverHome, Seed.peelamedu.location),
    ];
    await Future.wait([for (final (a, b) in pairs) fetch(a, b)]);
  }
}

/// Road route between [from] and [to] when available, else the curved stand-in.
/// Same signature as [curvedPath] so it can replace it anywhere.
List<LatLng> roadPath(LatLng from, LatLng to, {int segments = 48, double bend = 0.18}) {
  final hit = RoadRouter.cached(from, to);
  if (hit != null) return hit;
  unawaited(RoadRouter.fetch(from, to));
  return curvedPath(from, to, segments: segments, bend: bend);
}
