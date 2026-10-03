import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

/// Id of the pickup that stands in before the phone's location is known (no GPS fix yet, or location is off). It is
/// not a place: the apps say "Choose your pickup", and nothing is quoted or booked from it.
const String kUnknownPickupId = 'pickup-unknown';

/// A named point (a search result, a pin, a saved place, a trip's stop).
@immutable
class Place {
  const Place({
    required this.id,
    required this.name,
    required this.address,
    required this.location,
    this.landmark,
    this.distanceKm,
  });

  final String id;
  final String name;
  final String address;
  final LatLng location;

  /// Live API reverse geocode: a meeting point from Google's address descriptors ("Near KG Hospital").
  final String? landmark;

  /// Live API search suggestion: road distance from the pickup, when the app sent one (Places `distanceMeters`).
  final double? distanceKm;

  /// "Brookefields Mall, Krishnasamy Rd, RS Puram"
  String get fullAddress => '$name, $address';

  /// The stand-in pickup before the phone's location is known ([kUnknownPickupId]).
  bool get isUnknownPickup => id == kUnknownPickupId;

  Place copyWith({String? id, String? name, String? address, LatLng? location, String? landmark, double? distanceKm}) => Place(
        id: id ?? this.id,
        name: name ?? this.name,
        address: address ?? this.address,
        location: location ?? this.location,
        landmark: landmark ?? this.landmark,
        distanceKm: distanceKm ?? this.distanceKm,
      );

  @override
  bool operator ==(Object other) => other is Place && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Place($name)';
}

/// Icon hint for a saved place.
enum SavedPlaceKind { home, work, other }

/// A place the passenger saved (Home, Work, or a custom label).
@immutable
class SavedPlace {
  const SavedPlace({
    required this.id,
    required this.label,
    required this.kind,
    required this.place,
    this.note = '',
  });

  final String id;
  final String label;
  final SavedPlaceKind kind;
  final Place place;
  final String note;

  SavedPlace copyWith({
    String? id,
    String? label,
    SavedPlaceKind? kind,
    Place? place,
    String? note,
  }) => SavedPlace(
    id: id ?? this.id,
    label: label ?? this.label,
    kind: kind ?? this.kind,
    place: place ?? this.place,
    note: note ?? this.note,
  );
}
