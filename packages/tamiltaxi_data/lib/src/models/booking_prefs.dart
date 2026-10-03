import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import 'vehicle.dart';

/// A service a driver switches on or off, or pauses for a while (driver app › Services; the API's `ServiceKey`). The
/// vehicle's main service (rides; parcels for goods vehicles) is always on and isn't one of these.
enum DriverService {
  /// Bikes, scooters and autos: parcels too (two-wheelers on by default, autos off: it's their passenger seat).
  parcels,

  /// Cabs: rentals by the hour.
  rentals,

  /// Cabs: outstation trips; goods trucks: goods to another town.
  outstation,

  /// Goods trucks: Packers & Movers (off by default: they need helpers).
  shifting;

  /// The services [kind] can switch on and off (same as the API's `servicesFor`).
  static List<DriverService> availableFor(VehicleKind kind) => switch (kind) {
        VehicleKind.bike || VehicleKind.scooty || VehicleKind.auto => const [parcels],
        VehicleKind.cab || VehicleKind.sedan || VehicleKind.suv => const [rentals, outstation],
        VehicleKind.threeWheeler || VehicleKind.miniTruck || VehicleKind.pickup || VehicleKind.truck => const [outstation, shifting],
        _ => const [],
      };
}

/// A paused service: off until [until], or until the driver starts it again (null). [reason] is for us.
@immutable
class ServicePause {
  const ServicePause({this.until, this.reason});
  final DateTime? until;
  final String? reason;

  /// Still running at [now].
  bool runningAt(DateTime now) => until == null || until!.isAfter(now);

  static ServicePause? fromJson(Object? raw) {
    if (raw is! Map) return null;
    return ServicePause(
      until: raw['until'] is String ? DateTime.tryParse(raw['until'] as String)?.toLocal() : null,
      reason: raw['reason'] is String ? raw['reason'] as String : null,
    );
  }

  @override
  bool operator ==(Object other) => other is ServicePause && other.until == until && other.reason == reason;

  @override
  int get hashCode => Object.hash(until, reason);
}

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
    this.parcels,
    this.rentals,
    this.outstation,
    this.areas = const [],
    this.shifting = false,
    this.helpers = defaultHelpers,
    this.pauses = const {},
  });
  final double? maxPickupKm;
  final double? minTripKm;
  final double? maxTripKm;
  final GoToDestination? goTo;
  final StayInArea? stayIn;
  /// Parcels too, as the driver chose it; null: the vehicle's default ([isOn]).
  final bool? parcels;

  /// Rentals / outstation as chosen; null: on.
  final bool? rentals;
  final bool? outstation;
  final List<SavedArea> areas;
  final bool shifting;
  final int helpers;

  /// The services paused now (from the server; Services pauses them).
  final Map<DriverService, ServicePause> pauses;

  /// Whether [service] is on for a [kind] driver at [now] (same rules as the API's `serviceOn`).
  bool isOn(DriverService service, VehicleKind kind, DateTime now) {
    if (pauseOf(service, now) != null) return false;
    return switch (service) {
      DriverService.parcels => parcels ?? kind != VehicleKind.auto,
      DriverService.rentals => rentals ?? true,
      DriverService.outstation => outstation ?? true,
      DriverService.shifting => shifting,
    };
  }

  /// [service]'s pause still running at [now], else null.
  ServicePause? pauseOf(DriverService service, DateTime now) {
    final p = pauses[service];
    return p != null && p.runningAt(now) ? p : null;
  }

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
    bool? rentals,
    bool? outstation,
    List<SavedArea>? areas,
    bool? shifting,
    int? helpers,
    Map<DriverService, ServicePause>? pauses,
  }) =>
      BookingPrefs(
        maxPickupKm: maxPickupKm != null ? maxPickupKm() : this.maxPickupKm,
        minTripKm: minTripKm != null ? minTripKm() : this.minTripKm,
        maxTripKm: maxTripKm != null ? maxTripKm() : this.maxTripKm,
        goTo: goTo != null ? goTo() : this.goTo,
        stayIn: stayIn != null ? stayIn() : this.stayIn,
        parcels: parcels ?? this.parcels,
        rentals: rentals ?? this.rentals,
        outstation: outstation ?? this.outstation,
        areas: areas ?? this.areas,
        shifting: shifting ?? this.shifting,
        helpers: helpers ?? this.helpers,
        pauses: pauses ?? this.pauses,
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
        // Unset stays unset (an auto's parcels are off until switched on in Services). Rentals, outstation and the
        // pauses are set in Services (`PUT /drivers/me/services/…`); the server keeps them.
        'parcels': ?parcels,
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
      parcels: j['parcels'] is bool ? j['parcels'] as bool : null,
      rentals: j['rentals'] is bool ? j['rentals'] as bool : null,
      outstation: j['outstation'] is bool ? j['outstation'] as bool : null,
      pauses: {
        if (j['pauses'] is Map)
          for (final s in DriverService.values) s: ?ServicePause.fromJson((j['pauses'] as Map)[s.name]),
      },
      shifting: j['shifting'] == true,
      helpers: j['helpers'] is num ? (j['helpers'] as num).toInt().clamp(0, maxHelpers) : defaultHelpers,
      areas: [
        for (final a in (j['areas'] is List ? j['areas'] as List : const [])) ?SavedArea.fromJson(a),
      ],
    );
  }
}
