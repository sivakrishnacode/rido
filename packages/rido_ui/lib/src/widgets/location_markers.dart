import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/rido_colors.dart';
import '../theme/rido_tokens.dart';

/// Green pickup dot with a white ring (map + lists).
class PickupDot extends StatelessWidget {
  const PickupDot({super.key, this.size = 14});
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size + 8,
        height: size + 8,
        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: RidoShadows.soft),
        alignment: Alignment.center,
        child: Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(color: RidoColors.success, shape: BoxShape.circle),
        ),
      );
}

/// Coral drop pin.
class DropPin extends StatelessWidget {
  const DropPin({super.key, this.size = 22});
  final double size;

  @override
  Widget build(BuildContext context) =>
      Icon(Symbols.location_on_rounded, fill: 1, color: RidoColors.coral500, size: size);
}
