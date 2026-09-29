import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../models/place.dart';
import 'google_http.dart';
import 'google_maps_config.dart';

/// Places API (New) autocomplete + Place Details, and Geocoding API reverse geocoding.
///
/// Cost rules built in:
/// * one autocomplete **session token** per search session; the session ends with the
///   Place Details call ([placeDetails]), so the keystrokes are billed as one session;
/// * autocomplete is only sent for 3+ characters (callers also debounce ≥ 300 ms);
/// * Place Details asks for [detailsFieldMask] only;
/// * autocomplete results, details and reverse geocodes are cached in memory.
class GooglePlacesClient {
  GooglePlacesClient({String? apiKey, math.Random? random})
    : _key = apiKey ?? googleMapsApiKey,
      _rng = random ?? math.Random.secure();

  /// Shared instance used by the mock repositories when a key is configured.
  static final GooglePlacesClient shared = GooglePlacesClient();

  static const autocompleteUrl = 'https://places.googleapis.com/v1/places:autocomplete';
  static const detailsUrl = 'https://places.googleapis.com/v1/places';
  static const geocodeUrl = 'https://maps.googleapis.com/maps/api/geocode/json';

  /// Only what we show: name, address and coordinates.
  /// Essentials-only fields (no displayName, which bills at the Pro SKU); the name comes from the suggestion.
  static const detailsFieldMask = 'id,formattedAddress,location';
  static const autocompleteFieldMask =
      'suggestions.placePrediction.placeId,suggestions.placePrediction.text,suggestions.placePrediction.structuredFormat';

  /// Coimbatore city centre, 30 km bias circle.
  static const biasCentre = LatLng(11.0168, 76.9658);
  static const biasRadiusM = 30000.0;
  static const minQueryLength = 3;

  /// Prefix of place ids that still need [placeDetails] for their coordinates.
  static const idPrefix = 'g:';

  final String _key;
  final math.Random _rng;

  String? _session;
  DateTime? _sessionStarted;
  final Map<String, List<Place>> _autocompleteCache = {};
  final Map<String, Place> _detailsCache = {};
  final Map<String, Place> _geocodeCache = {};

  /// The current session token (created on the first autocomplete of a session).
  String get sessionToken {
    final started = _sessionStarted;
    // Google expires sessions after a few minutes; start a new one rather than reuse a stale one.
    if (_session == null || started == null || DateTime.now().difference(started) > const Duration(minutes: 3)) {
      _session = _uuidV4();
      _sessionStarted = DateTime.now();
    }
    return _session!;
  }

  /// Ends the current autocomplete session (done automatically by [placeDetails]).
  void endSession() {
    _session = null;
    _sessionStarted = null;
  }

  String _uuidV4() {
    final b = List<int>.generate(16, (_) => _rng.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  /// Autocomplete suggestions for [input]. Each result has id `g:<placeId>` and a placeholder
  /// [Place.location] (the city centre) until resolved with [placeDetails].
  Future<List<Place>> autocomplete(String input) async {
    final q = input.trim();
    if (q.length < minQueryLength) return const [];
    final cacheKey = q.toLowerCase();
    final hit = _autocompleteCache[cacheKey];
    if (hit != null) return hit;
    final json = await googleJsonRequest(
      'POST',
      Uri.parse(autocompleteUrl),
      headers: {'X-Goog-Api-Key': _key, 'X-Goog-FieldMask': autocompleteFieldMask},
      body: {
        'input': q,
        'sessionToken': sessionToken,
        'locationBias': {
          'circle': {
            'center': {'latitude': biasCentre.latitude, 'longitude': biasCentre.longitude},
            'radius': biasRadiusM,
          },
        },
        'includedRegionCodes': ['in'],
        'languageCode': 'en',
      },
    );
    final places = parseAutocomplete(json);
    if (_autocompleteCache.length > 200) _autocompleteCache.clear();
    return _autocompleteCache[cacheKey] = places;
  }

  /// Name, address and coordinates of [placeId] (without the `g:` prefix). Ends the session.
  Future<Place> placeDetails(String placeId) async {
    final hit = _detailsCache[placeId];
    if (hit != null) {
      endSession();
      return hit;
    }
    final token = _session;
    final uri = Uri.parse(
      '$detailsUrl/${Uri.encodeComponent(placeId)}',
    ).replace(queryParameters: {'sessionToken': ?token, 'languageCode': 'en'});
    final json = await googleJsonRequest(
      'GET',
      uri,
      headers: {'X-Goog-Api-Key': _key, 'X-Goog-FieldMask': detailsFieldMask},
    );
    endSession();
    final place = parsePlaceDetails(json);
    if (place == null) throw const FormatException('Place Details without a location');
    return _detailsCache[placeId] = place;
  }

  /// Nearest address to [point] (Geocoding API). Null when Google has no result.
  Future<Place?> reverseGeocode(LatLng point) async {
    // ~11 m grid, so nudging the pin a little reuses the last answer.
    final cacheKey = '${point.latitude.toStringAsFixed(4)},${point.longitude.toStringAsFixed(4)}';
    final hit = _geocodeCache[cacheKey];
    if (hit != null) return hit.copyWith(location: point);
    final uri = Uri.parse(
      geocodeUrl,
    ).replace(queryParameters: {'latlng': '${point.latitude},${point.longitude}', 'language': 'en', 'key': _key});
    final json = await googleJsonRequest('GET', uri);
    final place = parseGeocode(json, point);
    if (place != null) {
      if (_geocodeCache.length > 200) _geocodeCache.clear();
      _geocodeCache[cacheKey] = place;
    }
    return place;
  }

  // ---- JSON parsing (pure, unit tested) ----

  /// Parses a `places:autocomplete` response.
  static List<Place> parseAutocomplete(Object? json) {
    if (json is! Map) return const [];
    final suggestions = json['suggestions'];
    if (suggestions is! List) return const [];
    final out = <Place>[];
    for (final s in suggestions) {
      final p = s is Map ? s['placePrediction'] : null;
      if (p is! Map) continue;
      final id = p['placeId'];
      if (id is! String || id.isEmpty) continue;
      final structured = p['structuredFormat'];
      final full = _text(p['text']) ?? '';
      final main = structured is Map ? _text(structured['mainText']) : null;
      final secondary = structured is Map ? _text(structured['secondaryText']) : null;
      out.add(
        Place(
          id: '$idPrefix$id',
          name: main ?? full.split(',').first.trim(),
          address: _shortAddress(secondary ?? full.split(',').skip(1).join(',').trim()),
          location: biasCentre,
        ),
      );
    }
    return out;
  }

  /// Parses a Place Details (New) response; null without coordinates.
  static Place? parsePlaceDetails(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final loc = json['location'];
    if (id is! String || loc is! Map) return null;
    final lat = loc['latitude'];
    final lng = loc['longitude'];
    if (lat is! num || lng is! num) return null;
    final address = (json['formattedAddress'] as String?) ?? '';
    final name = _text(json['displayName']) ?? address.split(',').first.trim();
    var rest = address;
    if (rest.startsWith(name)) rest = rest.substring(name.length).replaceFirst(RegExp(r'^[,\s]+'), '');
    return Place(
      id: '$idPrefix$id',
      name: name,
      address: _shortAddress(rest.isEmpty ? address : rest),
      location: LatLng(lat.toDouble(), lng.toDouble()),
    );
  }

  /// Parses a Geocoding API reverse-geocode response into a place at [point]; null if no result.
  static Place? parseGeocode(Object? json, LatLng point) {
    if (json is! Map || json['status'] != 'OK') return null;
    final results = json['results'];
    if (results is! List) return null;
    for (final r in results) {
      if (r is! Map) continue;
      final types = (r['types'] as List?)?.cast<Object?>() ?? const [];
      if (types.contains('plus_code')) continue;
      final formatted = r['formatted_address'];
      if (formatted is! String || formatted.isEmpty) continue;
      final parts = formatted.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty && !_isPlusCode(s)).toList();
      if (parts.isEmpty) continue;
      final name = _componentName(r['address_components']) ?? parts.first;
      final rest = parts.where((p) => p != name).join(', ');
      return Place(
        id: 'geo:${point.latitude.toStringAsFixed(5)},${point.longitude.toStringAsFixed(5)}',
        name: name,
        address: _shortAddress(rest.isEmpty ? formatted : rest),
        location: point,
      );
    }
    return null;
  }

  static String? _text(Object? v) {
    if (v is Map) {
      final t = v['text'];
      if (t is String && t.trim().isNotEmpty) return t.trim();
    }
    return null;
  }

  static bool _isPlusCode(String s) => RegExp(r'^[23456789CFGHJMPQRVWX]{4,8}\+[23456789CFGHJMPQRVWX]{0,3}').hasMatch(s);

  /// Most specific human name from `address_components`.
  static String? _componentName(Object? components) {
    if (components is! List) return null;
    const preferred = [
      'point_of_interest',
      'establishment',
      'premise',
      'route',
      'sublocality_level_1',
      'sublocality',
      'locality',
    ];
    for (final type in preferred) {
      for (final c in components) {
        if (c is Map && (c['types'] as List?)?.contains(type) == true) {
          final n = c['long_name'];
          if (n is String && n.isNotEmpty && !_isPlusCode(n)) return n;
        }
      }
    }
    return null;
  }

  /// Drops the trailing ", Tamil Nadu 641012, India" noise the seed addresses don't have.
  static String _shortAddress(String address) {
    final parts = address.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    while (parts.length > 1 &&
        (parts.last == 'India' ||
            RegExp(r'^Tamil Nadu( \d{6})?$').hasMatch(parts.last) ||
            RegExp(r'^\d{6}$').hasMatch(parts.last))) {
      parts.removeLast();
    }
    return parts.join(', ');
  }
}
