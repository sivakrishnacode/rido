import 'package:flutter/widgets.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:rido_data/rido_data.dart';

/// UI helpers for [VehicleKind]: icon and display name.
extension VehicleKindUi on VehicleKind {
  /// Material Symbols Rounded icon used on cards, chips and markers.
  IconData get icon => switch (this) {
        VehicleKind.bike || VehicleKind.goodsBike => Symbols.two_wheeler_rounded,
        VehicleKind.auto => Symbols.electric_rickshaw_rounded,
        VehicleKind.cab => Symbols.local_taxi_rounded,
        VehicleKind.threeWheeler => Symbols.electric_rickshaw_rounded,
        VehicleKind.miniTruck => Symbols.local_shipping_rounded,
        VehicleKind.pickup => Symbols.airport_shuttle_rounded,
        VehicleKind.truck => Symbols.local_shipping_rounded,
      };

  /// "Bike", "Auto", "Cab", "3-wheeler", "Mini truck", "Pickup", "Truck".
  String get label => switch (this) {
        VehicleKind.bike || VehicleKind.goodsBike => 'Bike',
        VehicleKind.auto => 'Auto',
        VehicleKind.cab => 'Cab',
        VehicleKind.threeWheeler => '3-wheeler',
        VehicleKind.miniTruck => 'Mini truck',
        VehicleKind.pickup => 'Pickup',
        VehicleKind.truck => 'Truck',
      };

  /// Marker glyph class for the map.
  MapVehicleType get mapType => switch (this) {
        VehicleKind.bike || VehicleKind.goodsBike => MapVehicleType.bike,
        VehicleKind.auto || VehicleKind.threeWheeler => MapVehicleType.auto,
        VehicleKind.cab => MapVehicleType.car,
        VehicleKind.miniTruck || VehicleKind.pickup || VehicleKind.truck => MapVehicleType.truck,
      };
}

/// Top-down marker shapes (DS-06): bike, auto, car, truck.
enum MapVehicleType { bike, auto, car, truck }
