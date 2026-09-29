import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

/// Where a driver wants to head (home, their stand) while [until]: only trips that end near it or take them at least
/// halfway there are offered.
@immutable
class GoToDestination {
  const GoToDestination({required this.location, required this.name, this.until});
  final LatLng location;
  final String name;

  /// When the server switches it off (two hours after it was set); null before it's saved.
  final DateTime? until;

  Map<String, Object?> toJson() => {'lat': location.latitude, 'lng': location.longitude, 'name': name};

  static GoToDestination? fromJson(Object? raw) {
    if (raw is! Map || raw['lat'] is! num || raw['lng'] is! num) return null;
    return GoToDestination(
      location: LatLng((raw['lat'] as num).toDouble(), (raw['lng'] as num).toDouble()),
      name: '${raw['name'] ?? ''}',
      until: DateTime.tryParse('${raw['until']}')?.toLocal(),
    );
  }
}

/// The driver's booking preferences (`/drivers/me/booking-preferences`). Null = no filter.
@immutable
class BookingPrefs {
  const BookingPrefs({this.maxPickupKm, this.minTripKm, this.maxTripKm, this.goTo});
  final double? maxPickupKm;
  final double? minTripKm;
  final double? maxTripKm;
  final GoToDestination? goTo;

  bool get hasFilters => maxPickupKm != null || minTripKm != null || maxTripKm != null || goTo != null;

  /// "Pickup ≤ 2 km · trips over 5 km · going to Home": what's on, for the Home hint.
  String get summary => [
        if (goTo != null) 'going to ${goTo!.name}',
        if (maxPickupKm != null) 'pickup ≤ ${_km(maxPickupKm!)}',
        if (minTripKm != null && maxTripKm != null)
          'trips ${_km(minTripKm!, unit: false)}–${_km(maxTripKm!)}'
        else if (minTripKm != null)
          'trips over ${_km(minTripKm!)}'
        else if (maxTripKm != null)
          'trips under ${_km(maxTripKm!)}',
      ].join(' · ');

  static String _km(double km, {bool unit = true}) =>
      '${km == km.roundToDouble() ? km.toInt() : km.toStringAsFixed(1)}${unit ? ' km' : ''}';

  BookingPrefs copyWith({
    double? Function()? maxPickupKm,
    double? Function()? minTripKm,
    double? Function()? maxTripKm,
    GoToDestination? Function()? goTo,
  }) =>
      BookingPrefs(
        maxPickupKm: maxPickupKm != null ? maxPickupKm() : this.maxPickupKm,
        minTripKm: minTripKm != null ? minTripKm() : this.minTripKm,
        maxTripKm: maxTripKm != null ? maxTripKm() : this.maxTripKm,
        goTo: goTo != null ? goTo() : this.goTo,
      );

  Map<String, Object?> toJson() => {
        'maxPickupKm': maxPickupKm,
        'minTripKm': minTripKm,
        'maxTripKm': maxTripKm,
        'goTo': goTo?.toJson(),
      };

  factory BookingPrefs.fromJson(Map<String, dynamic> j) {
    double? km(Object? v) => v is num && v > 0 ? v.toDouble() : null;
    return BookingPrefs(
      maxPickupKm: km(j['maxPickupKm']),
      minTripKm: km(j['minTripKm']),
      maxTripKm: km(j['maxTripKm']),
      goTo: GoToDestination.fromJson(j['goTo']),
    );
  }
}
