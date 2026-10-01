import 'package:flutter/foundation.dart';

import 'people.dart';
import 'place.dart';
import '../ride_modes.dart';
import 'vehicle.dart';

enum TripKind { ride, parcel }

/// Lifecycle of a ride or parcel. Parcel trips use [atPickup] and [pickedUp];
/// rides use [driverArrived] and [inProgress]. [scheduled]: booked for later (rental, outstation), not yet searching.
enum TripStatus {
  scheduled,
  searching,
  driverAssigned,
  driverArrived,
  atPickup,
  inProgress,
  pickedUp,
  completed,
  delivered,
  cancelled;

  bool get isFinished => this == completed || this == delivered || this == cancelled;
  bool get isActive => !isFinished && this != searching && this != scheduled;
}

enum PaymentMode { cash, upi }

/// Who pays the goods driver.
enum ParcelPayer { sender, receiver }

/// "What are you sending?"
enum ParcelCategory {
  documents('Documents'),
  food('Food'),
  clothes('Clothes / Textiles'),
  electronics('Electronics'),
  household('Household'),
  furniture('Furniture'),
  other('Other');

  const ParcelCategory(this.label);
  final String label;
}

/// Weight choice chips on PP-04. [maxKg] is the upper bound used to filter vehicles.
enum WeightBand {
  under5('Under 5 kg', 5),
  from5to20('5–20 kg', 20),
  from20to100('20–100 kg', 100),
  from100to500('100–500 kg', 500),
  over500('500 kg+', 1500);

  const WeightBand(this.label, this.maxKg);
  final String label;
  final int maxKg;
}

@immutable
class ParcelDetails {
  const ParcelDetails({
    required this.category,
    required this.weight,
    required this.senderName,
    required this.senderPhone,
    required this.receiverName,
    required this.receiverPhone,
    this.pickupNote = '',
    this.dropNote = '',
    this.payer = ParcelPayer.sender,
    this.deliveryOtp = '7153',
    this.hasPhoto = false,
  });

  final ParcelCategory category;
  final WeightBand weight;
  final String senderName;
  final String senderPhone;
  final String receiverName;
  final String receiverPhone;

  /// Building / floor / landmark.
  final String pickupNote;
  final String dropNote;
  final ParcelPayer payer;
  final String deliveryOtp;
  final bool hasPhoto;

  ParcelDetails copyWith({
    ParcelCategory? category,
    WeightBand? weight,
    String? senderName,
    String? senderPhone,
    String? receiverName,
    String? receiverPhone,
    String? pickupNote,
    String? dropNote,
    ParcelPayer? payer,
    String? deliveryOtp,
    bool? hasPhoto,
  }) =>
      ParcelDetails(
        category: category ?? this.category,
        weight: weight ?? this.weight,
        senderName: senderName ?? this.senderName,
        senderPhone: senderPhone ?? this.senderPhone,
        receiverName: receiverName ?? this.receiverName,
        receiverPhone: receiverPhone ?? this.receiverPhone,
        pickupNote: pickupNote ?? this.pickupNote,
        dropNote: dropNote ?? this.dropNote,
        payer: payer ?? this.payer,
        deliveryOtp: deliveryOtp ?? this.deliveryOtp,
        hasPhoto: hasPhoto ?? this.hasPhoto,
      );
}

/// A ride or a parcel, past or current.
@immutable
class Trip {
  const Trip({
    required this.id,
    required this.kind,
    required this.vehicle,
    required this.pickup,
    required this.drop,
    required this.fare,
    required this.status,
    required this.startedAt,
    this.driver,
    this.quote,
    this.distanceKm = 0,
    this.durationMin = 0,
    this.otp = '4829',
    this.paymentMode = PaymentMode.cash,
    this.parcel,
    this.rating,
    this.pickupLabel,
    this.dropLabel,
    this.rideMode = RideMode.local,
    this.modeTerms,
    this.scheduledAt,
  });

  final String id;
  final TripKind kind;

  /// Local, rental (a cab by the hour) or outstation (another town).
  final RideMode rideMode;
  final ModeTerms? modeTerms;

  /// Pickup time of a trip booked for later.
  final DateTime? scheduledAt;
  final VehicleKind vehicle;
  final Place pickup;
  final Place drop;

  /// Total in whole rupees.
  final int fare;
  final TripStatus status;
  final DateTime startedAt;
  final DriverProfile? driver;
  final FareQuote? quote;
  final double distanceKm;
  final int durationMin;
  final String otp;
  final PaymentMode paymentMode;
  final ParcelDetails? parcel;
  final int? rating;

  /// Overrides for list display, e.g. "Home" instead of "Saibaba Colony".
  final String? pickupLabel;
  final String? dropLabel;

  bool get isParcel => kind == TripKind.parcel;
  String get fromLabel => pickupLabel ?? pickup.name;

  /// A rental has no drop: "Rental · 4 hrs · 40 km".
  String get toLabel => dropLabel ?? (modeTerms is RentalTerms ? 'Rental · ${(modeTerms! as RentalTerms).package.label}' : drop.name);

  Trip copyWith({
    String? id,
    TripKind? kind,
    VehicleKind? vehicle,
    Place? pickup,
    Place? drop,
    int? fare,
    TripStatus? status,
    DateTime? startedAt,
    DriverProfile? driver,
    FareQuote? quote,
    double? distanceKm,
    int? durationMin,
    String? otp,
    PaymentMode? paymentMode,
    ParcelDetails? parcel,
    int? rating,
    String? pickupLabel,
    String? dropLabel,
    RideMode? rideMode,
    ModeTerms? modeTerms,
    DateTime? scheduledAt,
  }) =>
      Trip(
        id: id ?? this.id,
        kind: kind ?? this.kind,
        vehicle: vehicle ?? this.vehicle,
        pickup: pickup ?? this.pickup,
        drop: drop ?? this.drop,
        fare: fare ?? this.fare,
        status: status ?? this.status,
        startedAt: startedAt ?? this.startedAt,
        driver: driver ?? this.driver,
        quote: quote ?? this.quote,
        distanceKm: distanceKm ?? this.distanceKm,
        durationMin: durationMin ?? this.durationMin,
        otp: otp ?? this.otp,
        paymentMode: paymentMode ?? this.paymentMode,
        parcel: parcel ?? this.parcel,
        rating: rating ?? this.rating,
        pickupLabel: pickupLabel ?? this.pickupLabel,
        dropLabel: dropLabel ?? this.dropLabel,
        rideMode: rideMode ?? this.rideMode,
        modeTerms: modeTerms ?? this.modeTerms,
        scheduledAt: scheduledAt ?? this.scheduledAt,
      );
}

@immutable
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.text,
    required this.fromMe,
    required this.sentAt,
  });

  final String id;
  final String text;
  final bool fromMe;
  final DateTime sentAt;

  ChatMessage copyWith({String? id, String? text, bool? fromMe, DateTime? sentAt}) => ChatMessage(
        id: id ?? this.id,
        text: text ?? this.text,
        fromMe: fromMe ?? this.fromMe,
        sentAt: sentAt ?? this.sentAt,
      );
}

enum TicketStatus {
  open('Open'),
  inProgress('In progress'),
  resolved('Resolved');

  const TicketStatus(this.label);
  final String label;
}

@immutable
class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.topic,
    required this.description,
    required this.status,
    required this.createdAt,
    this.tripId,
  });

  final String id;
  final String topic;
  final String description;
  final TicketStatus status;
  final DateTime createdAt;
  final String? tripId;

  SupportTicket copyWith({
    String? id,
    String? topic,
    String? description,
    TicketStatus? status,
    DateTime? createdAt,
    String? tripId,
  }) =>
      SupportTicket(
        id: id ?? this.id,
        topic: topic ?? this.topic,
        description: description ?? this.description,
        status: status ?? this.status,
        createdAt: createdAt ?? this.createdAt,
        tripId: tripId ?? this.tripId,
      );
}
