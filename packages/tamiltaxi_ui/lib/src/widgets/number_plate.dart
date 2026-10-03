import 'package:flutter/material.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';

import '../theme/tt_colors.dart';
import '../theme/tt_tokens.dart';

/// Indian HSRP-style number plate: black border, blue "IND" strip. Bikes and scooters ride on their white private
/// plate; every other vehicle (auto, cab, goods) is a T-board, the yellow commercial plate.
class NumberPlate extends StatelessWidget {
  const NumberPlate({super.key, required this.plate, this.vehicle, this.large = false});

  /// "TN 37 AB 4521"
  final String plate;

  /// The vehicle the plate is on: picks white or yellow. Null: white.
  final VehicleKind? vehicle;
  final bool large;

  /// The yellow of a T-board plate.
  static const tBoardYellow = Color(0xFFFFD21F);

  /// Whether [vehicle] carries a yellow T-board plate (everything but two-wheelers).
  static bool isTBoard(VehicleKind? vehicle) => vehicle != null && !vehicle.isTwoWheeler;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Semantics(
      label: 'Number plate $plate',
      excludeSemantics: true,
      child: Container(
        height: large ? 40 : 30,
        decoration: BoxDecoration(
          color: isTBoard(vehicle) ? tBoardYellow : Colors.white,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: TtColors.navy900, width: 1.6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: large ? 16 : 12,
              decoration: const BoxDecoration(
                color: Color(0xFF1D4ED8),
                borderRadius: BorderRadius.horizontal(left: Radius.circular(3)),
              ),
              alignment: Alignment.bottomCenter,
              padding: const EdgeInsets.only(bottom: 2),
              child: Text('IND', style: t.caption.copyWith(fontSize: large ? 6 : 5, color: Colors.white, height: 1)),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: large ? 12 : 8),
              child: Text(
                plate,
                style: TtTextStyles.tabular(
                  (large ? t.h2 : t.bodySemibold).copyWith(letterSpacing: 0.8, height: 1, fontSize: large ? 18 : 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
