import 'package:flutter/foundation.dart';

/// Every vehicle Rido supports. Ride vehicles carry passengers; goods vehicles carry parcels.
enum VehicleKind {
  bike,
  auto,
  cab,
  goodsBike,
  threeWheeler,
  miniTruck,
  pickup,
  truck;

  bool get isGoods => index >= VehicleKind.goodsBike.index;
  bool get isRide => !isGoods;
}

/// What a driver does on Rido: carry passengers or carry goods.
enum WorkType { rides, deliveries }

/// Per-vehicle fare rules. fare = max(minFare, base + perKm × km + perMin × min) × multiplier.
@immutable
class FareRule {
  const FareRule({
    required this.base,
    required this.perKm,
    required this.perMin,
    required this.minFare,
  });

  final int base;
  final double perKm;
  final double perMin;
  final int minFare;

  FareRule copyWith({int? base, double? perKm, double? perMin, int? minFare}) => FareRule(
        base: base ?? this.base,
        perKm: perKm ?? this.perKm,
        perMin: perMin ?? this.perMin,
        minFare: minFare ?? this.minFare,
      );
}

/// A bookable vehicle type (ride or goods).
@immutable
class VehicleType {
  const VehicleType({
    required this.kind,
    required this.name,
    required this.fareRule,
    required this.etaMin,
    this.seats,
    this.capacityKg,
    this.badge,
    this.modelHint,
    this.subscriptionPrice,
  });

  final VehicleKind kind;

  /// "Bike", "Auto", "3-wheeler", "Mini truck"…
  final String name;
  final FareRule fareRule;

  /// Minutes until the nearest driver can reach the pickup.
  final int etaMin;
  final int? seats;
  final int? capacityKg;

  /// "Lowest", "Comfort", "Best value"…
  final String? badge;

  /// "Tata Ace", "Bolero"…
  final String? modelHint;

  /// Driver subscription per month in rupees; null = price not decided ("₹—").
  final int? subscriptionPrice;

  bool get isGoods => kind.isGoods;

  /// "1 seat", "3 seats", "Up to 500 kg".
  String get capacityLabel {
    if (seats != null) return seats == 1 ? '1 seat' : '$seats seats';
    return 'Up to ${_kg(capacityKg ?? 0)} kg';
  }

  static String _kg(int kg) {
    if (kg < 1000) return '$kg';
    final s = kg.toString();
    return '${s.substring(0, s.length - 3)},${s.substring(s.length - 3)}';
  }

  VehicleType copyWith({
    VehicleKind? kind,
    String? name,
    FareRule? fareRule,
    int? etaMin,
    int? seats,
    int? capacityKg,
    String? badge,
    String? modelHint,
    int? subscriptionPrice,
  }) =>
      VehicleType(
        kind: kind ?? this.kind,
        name: name ?? this.name,
        fareRule: fareRule ?? this.fareRule,
        etaMin: etaMin ?? this.etaMin,
        seats: seats ?? this.seats,
        capacityKg: capacityKg ?? this.capacityKg,
        badge: badge ?? this.badge,
        modelHint: modelHint ?? this.modelHint,
        subscriptionPrice: subscriptionPrice ?? this.subscriptionPrice,
      );
}

/// A fully itemised fare. Every line is a whole rupee and the lines add up exactly to [total].
@immutable
class FareQuote {
  const FareQuote({
    required this.vehicle,
    required this.distanceKm,
    required this.durationMin,
    required this.base,
    required this.distanceCharge,
    required this.timeCharge,
    required this.subtotal,
    required this.multiplier,
    required this.peakCharge,
    required this.total,
    this.minFareTopUp = 0,
  });

  final VehicleType vehicle;
  final double distanceKm;
  final int durationMin;
  final int base;
  final int distanceCharge;
  final int timeCharge;

  /// Extra added when base + distance + time is below the minimum fare.
  final int minFareTopUp;
  final int subtotal;
  final double multiplier;
  final int peakCharge;
  final int total;

  bool get hasPeak => multiplier > 1.0 && peakCharge > 0;

  FareQuote copyWith({
    VehicleType? vehicle,
    double? distanceKm,
    int? durationMin,
    int? base,
    int? distanceCharge,
    int? timeCharge,
    int? minFareTopUp,
    int? subtotal,
    double? multiplier,
    int? peakCharge,
    int? total,
  }) =>
      FareQuote(
        vehicle: vehicle ?? this.vehicle,
        distanceKm: distanceKm ?? this.distanceKm,
        durationMin: durationMin ?? this.durationMin,
        base: base ?? this.base,
        distanceCharge: distanceCharge ?? this.distanceCharge,
        timeCharge: timeCharge ?? this.timeCharge,
        minFareTopUp: minFareTopUp ?? this.minFareTopUp,
        subtotal: subtotal ?? this.subtotal,
        multiplier: multiplier ?? this.multiplier,
        peakCharge: peakCharge ?? this.peakCharge,
        total: total ?? this.total,
      );
}
