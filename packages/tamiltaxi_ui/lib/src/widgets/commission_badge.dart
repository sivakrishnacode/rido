import 'package:flutter/material.dart';

import '../theme/tt_colors.dart';
import '../theme/tt_tokens.dart';

/// Small "0% commission" badge: coral-50 fill, coral-600 text.
class CommissionBadge extends StatelessWidget {
  const CommissionBadge({super.key, this.large = false});
  final bool large;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(horizontal: large ? 14 : 10, vertical: large ? 6 : 3),
        decoration: const BoxDecoration(color: TtColors.coral50, borderRadius: TtRadii.pillRadius),
        child: Text(
          '0% commission',
          style: (large ? context.type.bodySmallMedium : context.type.caption)
              .copyWith(color: TtColors.coral600, fontWeight: FontWeight.w700),
        ),
      );
}
