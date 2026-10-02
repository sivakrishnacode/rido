import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../providers.dart';
import '../seed.dart';

/// A city Tamil Taxi serves (`GET /cities`). No city is built into the apps: they all come from the API, so a new
/// city only needs adding in the admin panel.
@immutable
class ServiceCity {
  const ServiceCity({required this.id, required this.name, required this.state, required this.center});

  final String id;
  final String name;
  final String state;
  final LatLng center;

  factory ServiceCity.fromJson(Map<String, dynamic> j) => ServiceCity(
        id: '${j['id']}',
        name: '${j['name'] ?? ''}'.trim(),
        state: '${j['state'] ?? ''}'.trim(),
        center: LatLng((j['centerLat'] as num).toDouble(), (j['centerLng'] as num).toDouble()),
      );
}

/// Where a map starts before it knows anything better (no GPS fix, no pickup): the first service city's centre once
/// [serviceCitiesProvider] has loaded, all of India before that. Read by `TtMap` and placeholder places.
abstract final class CityDefaults {
  static const india = LatLng(22.35, 78.67);
  static LatLng center = india;
}

/// `GET /cities` itself. A failure is not kept: it is fetched again with [backgroundRetry].
final _serviceCitiesFetchProvider = FutureProvider<List<ServiceCity>>((ref) async {
  final json = await ref.watch(apiClientProvider).get('/cities');
  return [for (final c in json as List) ServiceCity.fromJson((c as Map).cast<String, dynamic>())];
}, retry: backgroundRetry);

/// The active service cities. Live: `GET /cities` (empty while unreachable; the next successful fetch fills it).
/// Mock: the seeded demo city.
final serviceCitiesProvider = FutureProvider<List<ServiceCity>>((ref) async {
  List<ServiceCity> cities;
  if (!ref.watch(isLiveApiProvider)) {
    cities = const [Seed.demoCity];
  } else {
    final fetched = ref.watch(_serviceCitiesFetchProvider);
    if (fetched case AsyncData(:final value)) {
      cities = value;
    } else if (fetched.hasError) {
      // Failing (and being fetched again in the background): none known until a fetch works.
      debugPrint('Cities unavailable: ${fetched.error}');
      cities = const [];
    } else {
      cities = await ref.watch(_serviceCitiesFetchProvider.future);
    }
  }
  if (cities.isNotEmpty) CityDefaults.center = cities.first.center;
  return cities;
});

/// "Coimbatore", "Coimbatore and Tiruppur", "Coimbatore, Tiruppur and Salem"; null when no city is known.
String? citiesLabel(List<ServiceCity> cities) {
  final names = [for (final c in cities) if (c.name.isNotEmpty) c.name];
  if (names.isEmpty) return null;
  if (names.length == 1) return names.first;
  return '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}';
}

/// The service city closest to [point] (null when there are none).
ServiceCity? nearestCity(List<ServiceCity> cities, LatLng point) {
  ServiceCity? best;
  var bestKm = double.infinity;
  for (final c in cities) {
    final km = const Distance().as(LengthUnit.Kilometer, point, c.center);
    if (km < bestKm) {
      bestKm = km;
      best = c;
    }
  }
  return best;
}

/// The cities' names for messages ("Choose a pickup in Coimbatore"), or "our service area" while none are known.
final serviceCitiesLabelProvider = Provider<String>(
  (ref) => citiesLabel(ref.watch(serviceCitiesProvider).value ?? const []) ?? 'our service area',
);
