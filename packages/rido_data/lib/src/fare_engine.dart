import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import 'models/place.dart';
import 'models/vehicle.dart';

/// Distance and duration between two places.
@immutable
class RouteEstimate {
  const RouteEstimate({required this.distanceKm, required this.durationMin});

  final double distanceKm;
  final int durationMin;

  /// "4.2 km · 14 min"
  String get label => '${distanceKm.toStringAsFixed(1)} km · $durationMin min';
}

/// Pure-Dart fare engine used by every screen that shows a price.
///
/// fare = max(minFare, base + perKm × km + perMin × min) × multiplier (capped at 1.5).
/// Every line is rounded DOWN to a whole rupee and the peak line is the difference,
/// so the breakdown always adds up exactly to the total.
abstract final class FareEngine {
  static const double roadFactor = 1.3;
  static const double averageSpeedKmh = 18;
  static const double maxMultiplier = 1.5;

  /// Current demand multiplier shown as "Peak time (1.1x)".
  static const double currentMultiplier = 1.1;

  static const double _eps = 1e-9;

  /// Measured road distances for the demo routes, so seed screens match the designs.
  /// Any other pair falls back to haversine × [roadFactor].
  static const Map<String, double> _knownRoutesKm = {
    'gandhipuram|brookefields': 4.2,
    'gandhipuram|brookefields-plaza': 4.4,
    'gandhipuram|brookebond-road': 4.0,
    'peelamedu|race-course': 6.8,
    'saibaba-colony|airport': 12.4,
    'rs-puram|junction': 3.6,
    'town-hall|ukkadam': 1.4,
    'psg-tech|tidel-park': 3.4,
  };

  static const Distance _distance = Distance();

  /// Straight-line distance × road factor, rounded to 0.1 km.
  static RouteEstimate estimate(Place from, Place to) {
    final known = _knownRoutesKm['${from.id}|${to.id}'] ?? _knownRoutesKm['${to.id}|${from.id}'];
    final km = known ?? roadDistanceKm(from.location, to.location);
    return RouteEstimate(distanceKm: km, durationMin: durationFor(km));
  }

  /// Haversine × 1.3, rounded to one decimal.
  static double roadDistanceKm(LatLng a, LatLng b) {
    final metres = _distance.as(LengthUnit.Meter, a, b);
    final km = metres / 1000 * roadFactor;
    return math.max(0.5, (km * 10).roundToDouble() / 10);
  }

  /// distance ÷ 18 km/h, in whole minutes (at least 1).
  static int durationFor(double km) => math.max(1, (km / averageSpeedKmh * 60).round());

  static int _floor(double v) => (v + _eps).floor();

  /// Builds the itemised quote for one vehicle.
  static FareQuote quote(VehicleType vehicle, RouteEstimate route, {double multiplier = currentMultiplier}) {
    final rule = vehicle.fareRule;
    final m = multiplier.clamp(1.0, maxMultiplier);
    final base = rule.base;
    final distanceCharge = _floor(rule.perKm * route.distanceKm);
    final timeCharge = _floor(rule.perMin * route.durationMin);
    final raw = base + distanceCharge + timeCharge;
    final topUp = math.max(0, rule.minFare - raw);
    final subtotal = raw + topUp;
    final total = _floor(subtotal * m);
    return FareQuote(
      vehicle: vehicle,
      distanceKm: route.distanceKm,
      durationMin: route.durationMin,
      base: base,
      distanceCharge: distanceCharge,
      timeCharge: timeCharge,
      minFareTopUp: topUp,
      subtotal: subtotal,
      multiplier: m,
      peakCharge: total - subtotal,
      total: total,
    );
  }

  /// Quotes for a list of vehicles along one route.
  static List<FareQuote> quoteAll(List<VehicleType> vehicles, RouteEstimate route,
          {double multiplier = currentMultiplier}) =>
      [for (final v in vehicles) quote(v, route, multiplier: multiplier)];
}
