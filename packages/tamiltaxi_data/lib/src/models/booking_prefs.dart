import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

/// A place the driver saved ("Home", "RS Puram stand") to switch Go To or Stay In on with one tap.
@immutable
class SavedArea {
  const SavedArea({required this.name, required this.location});
  final String name;
  final LatLng location;

  bool isAt(LatLng p) => location.latitude == p.latitude && location.longitude == p.longitude;

  Map<String, Object?> toJson() => {'name': name, 'lat': location.latitude, 'lng': location.longitude};

  static SavedArea? fromJson(Object? raw) {
    if (raw is! Map || raw['lat'] is! num || raw['lng'] is! num) return null;
    return SavedArea(
      name: '${raw['name'] ?? ''}',
      location: LatLng((raw['lat'] as num).toDouble(), (raw['lng'] as num).toDouble()),
    );
  }

  @override
  bool operator ==(Object other) => other is SavedArea && other.name == name && isAt(other.location);

  @override
  int get hashCode => Object.hash(name, location.latitude, location.longitude);
}

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

/// Stay In: while [until], only trips that start and end within [radiusKm] of [location].
@immutable
class StayInArea {
  const StayInArea({required this.location, required this.name, required this.radiusKm, this.until});
  final LatLng location;
  final String name;
  final double radiusKm;

  /// When the server switches it off (12 hours after it was set); null before it's saved.
  final DateTime? until;

  Map<String, Object?> toJson() =>
      {'lat': location.latitude, 'lng': location.longitude, 'name': name, 'radiusKm': radiusKm};

  static StayInArea? fromJson(Object? raw) {
    if (raw is! Map || raw['lat'] is! num || raw['lng'] is! num || raw['radiusKm'] is! num) return null;
    return StayInArea(
      location: LatLng((raw['lat'] as num).toDouble(), (raw['lng'] as num).toDouble()),
      name: '${raw['name'] ?? ''}',
      radiusKm: (raw['radiusKm'] as num).toDouble(),
      until: DateTime.tryParse('${raw['until']}')?.toLocal(),
    );
  }
}

/// The driver's booking preferences (`/drivers/me/booking-preferences`). Null = no filter. [goTo] and [stayIn] are
/// never on together. [parcels]: a bike driver also gets goods-bike parcels. [areas]: the saved places.
/// [shifting]: a goods-truck driver takes house shifting jobs, bringing up to [helpers] helpers (off by default: a
/// shift only goes to movers who switched it on with enough helpers).
@immutable
class BookingPrefs {
  const BookingPrefs({
    this.maxPickupKm,
    this.minTripKm,
    this.maxTripKm,
    this.goTo,
    this.stayIn,
    this.parcels = true,
    this.areas = const [],
    this.shifting = false,
    this.helpers = defaultHelpers,
  });
  final double? maxPickupKm;
  final double? minTripKm;
  final double? maxTripKm;
  final GoToDestination? goTo;
  final StayInArea? stayIn;
  final bool parcels;
  final List<SavedArea> areas;
  final bool shifting;
  final int helpers;

  /// Helpers a mover can say they bring (same as the API), and the start.
  static const maxHelpers = 8;
  static const defaultHelpers = 2;

  /// Saved areas a driver can keep (same as the API).
  static const maxAreas = 6;

  /// Go To or Stay In is on.
  bool get hasDirection => goTo != null || stayIn != null;

  /// Pickup distance or trip length limits are on.
  bool get hasTripFilters => maxPickupKm != null || minTripKm != null || maxTripKm != null;

  bool get hasFilters => hasTripFilters || hasDirection;

  /// "Going to Home · pickup ≤ 2 km · trips over 5 km": what's on, for Account.
  String get summary => [
        if (goTo != null) 'going to ${goTo!.name}',
        if (stayIn != null) 'staying in ${stayIn!.name}',
        if (hasTripFilters) tripFilterSummary,
        if (shifting) 'Packers & Movers with $helpers helper${helpers == 1 ? '' : 's'}',
      ].join(' · ');

  /// "Pickup ≤ 2 km · trips over 5 km": the limits alone (Home shows Go To / Stay In on their own strip).
  String get tripFilterSummary => [
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
    StayInArea? Function()? stayIn,
    bool? parcels,
    List<SavedArea>? areas,
    bool? shifting,
    int? helpers,
  }) =>
      BookingPrefs(
        maxPickupKm: maxPickupKm != null ? maxPickupKm() : this.maxPickupKm,
        minTripKm: minTripKm != null ? minTripKm() : this.minTripKm,
        maxTripKm: maxTripKm != null ? maxTripKm() : this.maxTripKm,
        goTo: goTo != null ? goTo() : this.goTo,
        stayIn: stayIn != null ? stayIn() : this.stayIn,
        parcels: parcels ?? this.parcels,
        areas: areas ?? this.areas,
        shifting: shifting ?? this.shifting,
        helpers: helpers ?? this.helpers,
      );

  /// Go To [area] (Stay In goes off), or neither when null.
  BookingPrefs goingTo(SavedArea? area) => copyWith(
        goTo: () => area == null ? null : GoToDestination(location: area.location, name: area.name),
        stayIn: () => null,
      );

  /// Stay In [area] within [radiusKm] (Go To goes off), or neither when null.
  BookingPrefs stayingIn(SavedArea? area, {double radiusKm = 5}) => copyWith(
        stayIn: () => area == null ? null : StayInArea(location: area.location, name: area.name, radiusKm: radiusKm),
        goTo: () => null,
      );

  Map<String, Object?> toJson() => {
        'maxPickupKm': maxPickupKm,
        'minTripKm': minTripKm,
        'maxTripKm': maxTripKm,
        'goTo': goTo?.toJson(),
        'stayIn': stayIn?.toJson(),
        'parcels': parcels,
        'areas': [for (final a in areas) a.toJson()],
        'shifting': shifting,
        'helpers': helpers,
      };

  factory BookingPrefs.fromJson(Map<String, dynamic> j) {
    double? km(Object? v) => v is num && v > 0 ? v.toDouble() : null;
    return BookingPrefs(
      maxPickupKm: km(j['maxPickupKm']),
      minTripKm: km(j['minTripKm']),
      maxTripKm: km(j['maxTripKm']),
      goTo: GoToDestination.fromJson(j['goTo']),
      stayIn: StayInArea.fromJson(j['stayIn']),
      parcels: j['parcels'] != false,
      shifting: j['shifting'] == true,
      helpers: j['helpers'] is num ? (j['helpers'] as num).toInt().clamp(0, maxHelpers) : defaultHelpers,
      areas: [
        for (final a in (j['areas'] is List ? j['areas'] as List : const [])) ?SavedArea.fromJson(a),
      ],
    );
  }
}
