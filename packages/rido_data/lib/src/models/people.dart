import 'package:flutter/foundation.dart';

import 'place.dart';
import 'vehicle.dart';

enum Gender { female, male, preferNotToSay }

/// Someone the passenger (or driver) trusts in an emergency.
@immutable
class EmergencyContact {
  const EmergencyContact({
    required this.id,
    required this.name,
    required this.relation,
    required this.phone,
  });

  final String id;
  final String name;
  final String relation;
  final String phone;

  EmergencyContact copyWith({String? id, String? name, String? relation, String? phone}) =>
      EmergencyContact(
        id: id ?? this.id,
        name: name ?? this.name,
        relation: relation ?? this.relation,
        phone: phone ?? this.phone,
      );
}

/// A Rido driver as seen by passengers and in the driver app.
@immutable
class DriverProfile {
  const DriverProfile({
    required this.id,
    required this.name,
    required this.phone,
    required this.vehicleKind,
    required this.vehicleModel,
    required this.vehicleColor,
    required this.plate,
    required this.rating,
    required this.rides,
    required this.upiId,
    this.gender = Gender.male,
  });

  final String id;
  final String name;
  final String phone;
  final VehicleKind vehicleKind;
  final String vehicleModel;
  final String vehicleColor;

  /// "TN 37 AB 4521"
  final String plate;
  final double rating;
  final int rides;
  final String upiId;
  final Gender gender;

  String get firstName => name.split(' ').first;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  /// "Honda Activa · Grey"
  String get vehicleLabel => vehicleColor.isEmpty ? vehicleModel : '$vehicleModel · $vehicleColor';

  DriverProfile copyWith({
    String? id,
    String? name,
    String? phone,
    VehicleKind? vehicleKind,
    String? vehicleModel,
    String? vehicleColor,
    String? plate,
    double? rating,
    int? rides,
    String? upiId,
    Gender? gender,
  }) =>
      DriverProfile(
        id: id ?? this.id,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        vehicleKind: vehicleKind ?? this.vehicleKind,
        vehicleModel: vehicleModel ?? this.vehicleModel,
        vehicleColor: vehicleColor ?? this.vehicleColor,
        plate: plate ?? this.plate,
        rating: rating ?? this.rating,
        rides: rides ?? this.rides,
        upiId: upiId ?? this.upiId,
        gender: gender ?? this.gender,
      );
}

/// The signed-in passenger.
@immutable
class PassengerProfile {
  const PassengerProfile({
    required this.name,
    required this.phone,
    required this.gender,
    this.email = '',
    this.rating = 4.9,
    this.savedPlaces = const [],
    this.emergencyContacts = const [],
    this.preferWomenDriver = false,
    this.autoShareTrips = true,
  });

  final String name;
  final String phone;
  final String email;
  final Gender gender;
  final double rating;
  final List<SavedPlace> savedPlaces;
  final List<EmergencyContact> emergencyContacts;
  final bool preferWomenDriver;
  final bool autoShareTrips;

  String get firstName => name.split(' ').first;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  PassengerProfile copyWith({
    String? name,
    String? phone,
    String? email,
    Gender? gender,
    double? rating,
    List<SavedPlace>? savedPlaces,
    List<EmergencyContact>? emergencyContacts,
    bool? preferWomenDriver,
    bool? autoShareTrips,
  }) =>
      PassengerProfile(
        name: name ?? this.name,
        phone: phone ?? this.phone,
        email: email ?? this.email,
        gender: gender ?? this.gender,
        rating: rating ?? this.rating,
        savedPlaces: savedPlaces ?? this.savedPlaces,
        emergencyContacts: emergencyContacts ?? this.emergencyContacts,
        preferWomenDriver: preferWomenDriver ?? this.preferWomenDriver,
        autoShareTrips: autoShareTrips ?? this.autoShareTrips,
      );
}
