import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

/// A named point in Coimbatore.
@immutable
class Place {
  const Place({
    required this.id,
    required this.name,
    required this.address,
    required this.location,
  });

  final String id;
  final String name;
  final String address;
  final LatLng location;

  /// "Brookefields Mall, Krishnasamy Rd, RS Puram"
  String get fullAddress => '$name, $address';

  Place copyWith({String? id, String? name, String? address, LatLng? location}) => Place(
        id: id ?? this.id,
        name: name ?? this.name,
        address: address ?? this.address,
        location: location ?? this.location,
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
  });

  final String id;
  final String label;
  final SavedPlaceKind kind;
  final Place place;

  SavedPlace copyWith({String? id, String? label, SavedPlaceKind? kind, Place? place}) => SavedPlace(
        id: id ?? this.id,
        label: label ?? this.label,
        kind: kind ?? this.kind,
        place: place ?? this.place,
      );
}
