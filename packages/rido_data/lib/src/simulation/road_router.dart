import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:latlong2/latlong.dart';

import '../maps/google_http.dart';
import '../maps/google_maps_config.dart';
import '../maps/polyline_codec.dart';
import '../models/vehicle.dart';
import '../seed.dart';
import 'trip_simulator.dart';

/// How the Routes API should route a leg (bikes may use two-wheeler shortcuts).
enum RouteTravelMode { drive, twoWheeler }

/// A router on the Rido backend (`POST /maps/route`): Google Routes with a server key and Redis cache.
typedef BackendRouter = Future<List<LatLng>?> Function(LatLng from, LatLng to, RouteTravelMode mode);

/// Road-following routes, cached in memory: the Rido backend when [backend] is set (live API: no Google key in
/// the app), else Google Routes API when an app key is configured ([isGoogleMapsEnabled]), else the free public
/// OSRM router, else null (curved stand-in).
///
/// Cost rules: each leg (from → to) is computed **once** per app session and then only read
/// from the cache (the trip simulator animates along it locally); concurrent requests for the
/// same leg share one call; a failed leg is not retried for [_retryAfter]; a key/config error
/// turns Google routing off for the session.
///
/// [roadPath] is synchronous: it returns the cached road route if we have one, otherwise the
/// curved stand-in from [curvedPath] and starts fetching the real route in the background.
/// Offline (or in tests, where [enabled] is false) the curved line is used.
abstract final class RoadRouter {
  static bool enabled = true;

  /// Set by the apps with the live API ([backendRouter]).
  static BackendRouter? backend;
  static const _osrmBase = 'https://router.project-osrm.org/route/v1/driving';
  static const googleRoutesUrl = 'https://routes.googleapis.com/directions/v2:computeRoutes';
  static const googleFieldMask = 'routes.distanceMeters,routes.duration,routes.polyline.encodedPolyline';
  static const _retryAfter = Duration(minutes: 2);

  static final Map<String, List<LatLng>> _cache = {};
  static final Map<String, Future<List<LatLng>?>> _inFlight = {};
  static final Map<String, DateTime> _failedAt = {};
  static bool _googleBroken = false;

  static String _key(LatLng a, LatLng b) =>
      '${a.latitude.toStringAsFixed(5)},${a.longitude.toStringAsFixed(5)}|'
      '${b.latitude.toStringAsFixed(5)},${b.longitude.toStringAsFixed(5)}';

  /// Cached road route, if already fetched.
  static List<LatLng>? cached(LatLng a, LatLng b) => _cache[_key(a, b)];

  /// Fetches (once) and caches the road route; null if routing is unavailable.
  /// [useGoogle] false forces the free OSRM router (used for the demo-route prefetch).
  static Future<List<LatLng>?> fetch(
    LatLng a,
    LatLng b, {
    RouteTravelMode mode = RouteTravelMode.drive,
    bool useGoogle = true,
  }) {
    final key = _key(a, b);
    final hit = _cache[key];
    if (hit != null) return Future.value(hit);
    if (!enabled) return Future.value(null);
    final failed = _failedAt[key];
    if (failed != null && DateTime.now().difference(failed) < _retryAfter) return Future.value(null);
    return _inFlight[key] ??= _get(a, b, mode, useGoogle).then((p) {
      _inFlight.remove(key);
      if (p != null) {
        _cache[key] = p;
        _failedAt.remove(key);
      } else {
        _failedAt[key] = DateTime.now();
      }
      return p;
    });
  }

  static Future<List<LatLng>?> _get(LatLng a, LatLng b, RouteTravelMode mode, bool useGoogle) async {
    final viaBackend = backend;
    if (useGoogle && viaBackend != null) {
      try {
        final p = await viaBackend(a, b, mode);
        if (p != null && p.length >= 2) return p;
      } catch (_) {
        // Fall through to OSRM.
      }
      return _osrm(a, b);
    }
    if (useGoogle && isGoogleMapsEnabled && !_googleBroken) {
      final g = await _google(a, b, mode);
      if (g != null) return g;
    }
    return _osrm(a, b);
  }

  /// Routes API computeRoutes, TRAFFIC_UNAWARE (Essentials SKU), polyline only.
  static Future<List<LatLng>?> _google(LatLng a, LatLng b, RouteTravelMode mode) async {
    Map<String, Object> wp(LatLng p) => {
      'location': {
        'latLng': {'latitude': p.latitude, 'longitude': p.longitude},
      },
    };
    try {
      final json = await googleJsonRequest(
        'POST',
        Uri.parse(googleRoutesUrl),
        headers: {'X-Goog-Api-Key': googleMapsApiKey, 'X-Goog-FieldMask': googleFieldMask},
        body: {
          'origin': wp(a),
          'destination': wp(b),
          'travelMode': mode == RouteTravelMode.twoWheeler ? 'TWO_WHEELER' : 'DRIVE',
          'routingPreference': 'TRAFFIC_UNAWARE',
          'computeAlternativeRoutes': false,
          'languageCode': 'en-IN',
          'units': 'METRIC',
        },
      );
      return parseGoogleRoute(json);
    } on GoogleApiException catch (e) {
      if (e.isConfigError) _googleBroken = true;
      return null;
    } catch (_) {
      return null;
    }
  }

  /// First route's decoded polyline from a computeRoutes response; null if missing.
  static List<LatLng>? parseGoogleRoute(Object? json) {
    if (json is! Map) return null;
    final routes = json['routes'];
    if (routes is! List || routes.isEmpty) return null;
    final first = routes.first;
    final polyline = first is Map ? first['polyline'] : null;
    final encoded = polyline is Map ? polyline['encodedPolyline'] : null;
    if (encoded is! String || encoded.isEmpty) return null;
    final pts = decodePolyline(encoded);
    return pts.length >= 2 ? pts : null;
  }

  static Future<List<LatLng>?> _osrm(LatLng a, LatLng b) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final uri = Uri.parse(
        '$_osrmBase/${a.longitude},${a.latitude};${b.longitude},${b.latitude}'
        '?overview=full&geometries=geojson',
      );
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

  /// Warms the cache with every route the demo flows draw. Uses the free OSRM router only, so
  /// app start never spends Routes API calls on the fixed demo legs.
  static Future<void> prefetchDemoRoutes() async {
    final pairs = <(LatLng, LatLng)>[
      (Seed.gandhipuram.location, Seed.brookefields.location),
      (offsetPoint(Seed.gandhipuram.location, 900, 35), Seed.gandhipuram.location),
      (Seed.peelamedu.location, Seed.raceCourse.location),
      (offsetPoint(Seed.peelamedu.location, 1100, 210), Seed.peelamedu.location),
      (Seed.driverHome, Seed.gandhipuram.location),
      (Seed.driverHome, Seed.peelamedu.location),
    ];
    await Future.wait([for (final (a, b) in pairs) fetch(a, b, useGoogle: false)]);
  }
}

/// Road route between [from] and [to] when available, else the curved stand-in.
/// Same signature as [curvedPath] (plus [mode]) so it can replace it anywhere.
List<LatLng> roadPath(
  LatLng from,
  LatLng to, {
  int segments = 48,
  double bend = 0.18,
  RouteTravelMode mode = RouteTravelMode.drive,
}) {
  final hit = RoadRouter.cached(from, to);
  if (hit != null) return hit;
  unawaited(RoadRouter.fetch(from, to, mode: mode));
  return curvedPath(from, to, segments: segments, bend: bend);
}

/// Bikes (rides and goods) may take two-wheeler shortcuts; everything else drives.
RouteTravelMode travelModeFor(VehicleKind kind) =>
    kind == VehicleKind.bike || kind == VehicleKind.goodsBike ? RouteTravelMode.twoWheeler : RouteTravelMode.drive;
