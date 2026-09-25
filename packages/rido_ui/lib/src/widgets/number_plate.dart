import 'package:flutter/material.dart';

import '../theme/rido_colors.dart';
import '../theme/rido_tokens.dart';

/// Indian HSRP-style number plate: white plate, black border, blue "IND" strip.
class NumberPlate extends StatelessWidget {
  const NumberPlate({super.key, required this.plate, this.large = false});

  /// "TN 37 AB 4521"
  final String plate;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Semantics(
      label: 'Number plate $plate',
      excludeSemantics: true,
      child: Container(
        height: large ? 40 : 30,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: RidoColors.navy900, width: 1.6),
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
                style: RidoTextStyles.tabular(
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
