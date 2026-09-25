import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/rido_colors.dart';
import '../theme/rido_tokens.dart';

/// SOS button: always a filled #DC2626 circle with a white icon and the label "SOS".
class SosButton extends StatelessWidget {
  const SosButton({super.key, required this.onPressed, this.size = 64});

  final VoidCallback onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'SOS emergency help',
      excludeSemantics: true,
      child: Material(
        key: const ValueKey('sos-button'),
        color: RidoColors.sos,
        shape: const CircleBorder(),
        elevation: 4,
        shadowColor: const Color(0x66DC2626),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: size,
            height: size,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Symbols.e911_emergency_rounded, fill: 1, color: Colors.white, size: size * 0.36),
                Text(
                  'SOS',
                  style: context.type.caption.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: size * 0.2,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
