import 'package:flutter/foundation.dart';

import 'place.dart';
import 'trip.dart';
import 'vehicle.dart';

/// Driver subscription status. [paused] and [cancelled] back the D-24b / D-24c frames.
enum PlanStatus {
  trial('Free trial'),
  active('Active'),
  grace('Grace'),
  expired('Expired'),
  paused('Paused'),
  cancelled('Cancelled');

  const PlanStatus(this.label);
  final String label;

  /// Whether the driver may go online.
  bool get canGoOnline => this != expired && this != paused;
}

@immutable
class SubscriptionPlan {
  const SubscriptionPlan({
    required this.vehicle,
    required this.monthlyPrice,
    required this.status,
    required this.startedAt,
    required this.nextDebit,
    this.upiApp = 'GPay',
    this.graceDaysLeft = 2,
  });

  final VehicleKind vehicle;

  /// Null when the price is not decided yet ("₹—").
  final int? monthlyPrice;
  final PlanStatus status;
  final DateTime startedAt;
  final DateTime nextDebit;
  final String upiApp;
  final int graceDaysLeft;

  SubscriptionPlan copyWith({
    VehicleKind? vehicle,
    int? monthlyPrice,
    PlanStatus? status,
    DateTime? startedAt,
    DateTime? nextDebit,
    String? upiApp,
    int? graceDaysLeft,
  }) =>
      SubscriptionPlan(
        vehicle: vehicle ?? this.vehicle,
        monthlyPrice: monthlyPrice ?? this.monthlyPrice,
        status: status ?? this.status,
        startedAt: startedAt ?? this.startedAt,
        nextDebit: nextDebit ?? this.nextDebit,
        upiApp: upiApp ?? this.upiApp,
        graceDaysLeft: graceDaysLeft ?? this.graceDaysLeft,
      );
}

enum PaymentRecordStatus { paid, freeTrial, failed }

@immutable
class PaymentRecord {
  const PaymentRecord({
    required this.label,
    required this.amount,
    required this.status,
    required this.date,
  });

  /// "Aug 2026"
  final String label;
  final int amount;
  final PaymentRecordStatus status;
  final DateTime date;

  PaymentRecord copyWith({String? label, int? amount, PaymentRecordStatus? status, DateTime? date}) =>
      PaymentRecord(
        label: label ?? this.label,
        amount: amount ?? this.amount,
        status: status ?? this.status,
        date: date ?? this.date,
      );
}

enum KycDocType {
  drivingLicence('Driving licence'),
  aadhaar('Aadhaar'),
  vehicleRc('Vehicle RC'),
  insurance('Vehicle insurance'),
  policeVerification('Police verification certificate');

  const KycDocType(this.label);
  final String label;
}

enum KycStatus { notUploaded, underReview, verified, rejected }

@immutable
class KycDocument {
  const KycDocument({required this.type, required this.status, this.rejectReason});

  final KycDocType type;
  final KycStatus status;
  final String? rejectReason;

  bool get isUploaded => status != KycStatus.notUploaded;

  KycDocument copyWith({KycDocType? type, KycStatus? status, String? rejectReason}) => KycDocument(
        type: type ?? this.type,
        status: status ?? this.status,
        rejectReason: rejectReason ?? this.rejectReason,
      );
}

/// One bar of the earnings chart.
@immutable
class EarningsDay {
  const EarningsDay({required this.label, required this.amount, this.rides = 0});

  /// "Mon", "W1", "9 AM"…
  final String label;
  final int amount;
  final int rides;

  EarningsDay copyWith({String? label, int? amount, int? rides}) =>
      EarningsDay(label: label ?? this.label, amount: amount ?? this.amount, rides: rides ?? this.rides);
}

/// A completed job in the driver's earnings list.
@immutable
class EarningsTrip {
  const EarningsTrip({
    required this.id,
    required this.time,
    required this.from,
    required this.to,
    required this.fare,
    required this.paymentMode,
    this.distanceKm = 0,
    this.durationMin = 0,
    this.passengerName = '',
    this.isDelivery = false,
  });

  final String id;
  final DateTime time;
  final String from;
  final String to;
  final int fare;
  final PaymentMode paymentMode;
  final double distanceKm;
  final int durationMin;
  final String passengerName;
  final bool isDelivery;

  EarningsTrip copyWith({
    String? id,
    DateTime? time,
    String? from,
    String? to,
    int? fare,
    PaymentMode? paymentMode,
    double? distanceKm,
    int? durationMin,
    String? passengerName,
    bool? isDelivery,
  }) =>
      EarningsTrip(
        id: id ?? this.id,
        time: time ?? this.time,
        from: from ?? this.from,
        to: to ?? this.to,
        fare: fare ?? this.fare,
        paymentMode: paymentMode ?? this.paymentMode,
        distanceKm: distanceKm ?? this.distanceKm,
        durationMin: durationMin ?? this.durationMin,
        passengerName: passengerName ?? this.passengerName,
        isDelivery: isDelivery ?? this.isDelivery,
      );
}

/// Summary for a Today / Week / Month tab.
@immutable
class EarningsSummary {
  const EarningsSummary({
    required this.total,
    required this.rides,
    required this.onlineHours,
    required this.rating,
    required this.bars,
    required this.trips,
    required this.commissionSaved,
  });

  final int total;
  final int rides;
  final int onlineHours;
  final double rating;
  final List<EarningsDay> bars;
  final List<EarningsTrip> trips;
  final int commissionSaved;

  EarningsSummary copyWith({
    int? total,
    int? rides,
    int? onlineHours,
    double? rating,
    List<EarningsDay>? bars,
    List<EarningsTrip>? trips,
    int? commissionSaved,
  }) =>
      EarningsSummary(
        total: total ?? this.total,
        rides: rides ?? this.rides,
        onlineHours: onlineHours ?? this.onlineHours,
        rating: rating ?? this.rating,
        bars: bars ?? this.bars,
        trips: trips ?? this.trips,
        commissionSaved: commissionSaved ?? this.commissionSaved,
      );
}

/// An incoming job offer shown on D-15 / D-20.
@immutable
class RideRequest {
  const RideRequest({
    required this.id,
    required this.kind,
    required this.vehicle,
    required this.fare,
    required this.pickup,
    required this.drop,
    required this.pickupDistanceKm,
    required this.pickupEtaMin,
    required this.tripKm,
    required this.tripMin,
    required this.customerName,
    required this.customerRating,
    this.customerPhone = '',
    this.parcel,
    this.otp = '4829',
  });

  final String id;
  final TripKind kind;
  final VehicleKind vehicle;
  final int fare;
  final Place pickup;
  final Place drop;
  final double pickupDistanceKm;
  final int pickupEtaMin;
  final double tripKm;
  final int tripMin;

  /// Passenger (rides) or receiver (deliveries).
  final String customerName;
  final double customerRating;
  final String customerPhone;
  final ParcelDetails? parcel;
  final String otp;

  bool get isDelivery => kind == TripKind.parcel;

  RideRequest copyWith({
    String? id,
    TripKind? kind,
    VehicleKind? vehicle,
    int? fare,
    Place? pickup,
    Place? drop,
    double? pickupDistanceKm,
    int? pickupEtaMin,
    double? tripKm,
    int? tripMin,
    String? customerName,
    double? customerRating,
    String? customerPhone,
    ParcelDetails? parcel,
    String? otp,
  }) =>
      RideRequest(
        id: id ?? this.id,
        kind: kind ?? this.kind,
        vehicle: vehicle ?? this.vehicle,
        fare: fare ?? this.fare,
        pickup: pickup ?? this.pickup,
        drop: drop ?? this.drop,
        pickupDistanceKm: pickupDistanceKm ?? this.pickupDistanceKm,
        pickupEtaMin: pickupEtaMin ?? this.pickupEtaMin,
        tripKm: tripKm ?? this.tripKm,
        tripMin: tripMin ?? this.tripMin,
        customerName: customerName ?? this.customerName,
        customerRating: customerRating ?? this.customerRating,
        customerPhone: customerPhone ?? this.customerPhone,
        parcel: parcel ?? this.parcel,
        otp: otp ?? this.otp,
      );
}
