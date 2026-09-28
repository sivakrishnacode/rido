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

/// Per-vehicle fare rules. fare = max(minFare, (base + perKm × km + perMin × min) × multiplier).
@immutable
class FareRule {
  const FareRule({
    required this.base,
    required this.perKm,
    required this.perMin,
    required this.minFare,
    this.waitPerMin = 1,
  });

  final int base;
  final double perKm;
  final double perMin;
  final int minFare;

  /// Waiting charge: rupees per started minute at the pickup after the free minutes.
  final int waitPerMin;

  FareRule copyWith({int? base, double? perKm, double? perMin, int? minFare, int? waitPerMin}) => FareRule(
        base: base ?? this.base,
        perKm: perKm ?? this.perKm,
        perMin: perMin ?? this.perMin,
        minFare: minFare ?? this.minFare,
        waitPerMin: waitPerMin ?? this.waitPerMin,
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

/// A fully itemised fare. Every line is a whole rupee and the lines add up exactly to [total]:
/// subtotal + peakCharge + waitingCharge + previousCancellationFee = total.
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
    this.pickupEtaMin,
    this.waitingCharge = 0,
    this.freeWaitMin = 3,
    this.waitPerMin = 0,
    this.waitMaxCharge = 30,
    this.previousCancellationFee = 0,
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

  /// Vehicle list only: minutes until the nearest free driver of this vehicle reaches the pickup
  /// (live: measured by the server; null = nobody near right now).
  final int? pickupEtaMin;

  /// Paid for waiting at the pickup past the free minutes (never surged); set on the trip's fare when it starts.
  final int waitingCharge;

  /// The waiting terms quoted with this fare: free minutes, rupees per started minute after them, and the cap.
  final int freeWaitMin;
  final int waitPerMin;
  final int waitMaxCharge;

  /// The passenger's earlier cancellation fee, added to this completed ride (the driver collects it in cash).
  final int previousCancellationFee;

  bool get hasPeak => multiplier > 1.0 && peakCharge > 0;

  /// Show the "Waiting charge" line only when there is one.
  bool get hasWaiting => waitingCharge > 0;

  /// Show the "Previous cancellation fee" line only when there is one.
  bool get hasCancellationFee => previousCancellationFee > 0;

  /// The waiting timer for a driver who arrived at [arrivedAt], on this fare's terms.
  WaitingTerms waitingFrom(DateTime arrivedAt) =>
      WaitingTerms(arrivedAt: arrivedAt, freeMin: freeWaitMin, perMin: waitPerMin, maxCharge: waitMaxCharge);

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
    int? pickupEtaMin,
    int? waitingCharge,
    int? freeWaitMin,
    int? waitPerMin,
    int? waitMaxCharge,
    int? previousCancellationFee,
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
        pickupEtaMin: pickupEtaMin ?? this.pickupEtaMin,
        waitingCharge: waitingCharge ?? this.waitingCharge,
        freeWaitMin: freeWaitMin ?? this.freeWaitMin,
        waitPerMin: waitPerMin ?? this.waitPerMin,
        waitMaxCharge: waitMaxCharge ?? this.waitMaxCharge,
        previousCancellationFee: previousCancellationFee ?? this.previousCancellationFee,
      );
}

/// The waiting timer at the pickup: the first [freeMin] minutes after [arrivedAt] are free, then every started
/// minute costs [perMin] rupees, up to [maxCharge] (same rule as the API's `waitingCharge`).
@immutable
class WaitingTerms {
  const WaitingTerms({required this.arrivedAt, this.freeMin = 3, this.perMin = 1, this.maxCharge = 30});

  final DateTime arrivedAt;
  final int freeMin;
  final int perMin;
  final int maxCharge;

  /// Free waiting left at [now] (zero once it is over).
  Duration freeLeft(DateTime now) {
    final left = arrivedAt.add(Duration(minutes: freeMin)).difference(now);
    return left.isNegative ? Duration.zero : left;
  }

  /// The waiting charge if the ride started at [now].
  int chargeAt(DateTime now) => waitingChargeFor(
        waited: now.difference(arrivedAt),
        freeMin: freeMin,
        perMin: perMin,
        maxCharge: maxCharge,
      );

  /// Nothing is ever charged (rate or cap of 0).
  bool get isFree => perMin <= 0 || maxCharge <= 0;
}

/// Waiting charge for [waited] at the pickup: [freeMin] free minutes, then [perMin] per started minute, capped at
/// [maxCharge]. 3 free at ₹1: 3:00 → ₹0, 3:01 → ₹1, 5:30 → ₹3.
int waitingChargeFor({required Duration waited, required int freeMin, required int perMin, required int maxCharge}) {
  final overMs = waited.inMilliseconds - freeMin * 60000;
  if (overMs <= 0 || perMin <= 0 || maxCharge <= 0) return 0;
  final minutes = (overMs / 60000 - 1e-9).ceil();
  final charge = minutes * perMin;
  return charge < maxCharge ? charge : maxCharge;
}
