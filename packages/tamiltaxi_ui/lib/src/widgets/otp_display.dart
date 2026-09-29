import 'package:flutter/material.dart';

import '../theme/tt_colors.dart';
import '../theme/tt_tokens.dart';

/// Read-only OTP box: "Ride OTP  4 8 2 9" on coral-50 with big tabular digits.
class OtpDisplay extends StatelessWidget {
  const OtpDisplay({super.key, required this.label, required this.code, this.caption, this.emphasised = false});

  final String label;
  final String code;
  final String? caption;

  /// Stronger border + larger digits (P-15 "Driver has arrived").
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Semantics(
      label: '$label ${code.split('').join(' ')}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: TtColors.coral50,
          borderRadius: TtRadii.cardRadius,
          border: Border.all(color: emphasised ? TtColors.coral600 : TtColors.coral100, width: emphasised ? 2 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(label, style: t.bodySemibold.copyWith(color: TtColors.coral600))),
                for (final d in code.split(''))
                  Container(
                    margin: const EdgeInsets.only(left: 6),
                    width: emphasised ? 44 : 38,
                    height: emphasised ? 52 : 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: TtColors.surface, borderRadius: BorderRadius.circular(10)),
                    child: Text(d, style: TtTextStyles.tabular(t.h1.copyWith(fontSize: emphasised ? 28 : 24))),
                  ),
              ],
            ),
            if (caption != null) ...[
              const SizedBox(height: 8),
              Text(caption!, style: t.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}
