import 'package:flutter/material.dart';

import '../theme/tt_colors.dart';
import '../theme/tt_tokens.dart';

/// White card with a 1px divider border and 12px radius. Tappable when [onTap] is set.
class TtCard extends StatelessWidget {
  const TtCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.color = TtColors.surface,
    this.borderColor = TtColors.divider,
    this.shadow = false,
    this.margin,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final Color color;
  final Color? borderColor;
  final bool shadow;
  final EdgeInsets? margin;

  @override
  Widget build(BuildContext context) {
    final card = DecoratedBox(
      decoration: BoxDecoration(borderRadius: TtRadii.cardRadius, boxShadow: shadow ? TtShadows.soft : null),
      child: Material(
        color: color,
        shape: RoundedRectangleBorder(
          borderRadius: TtRadii.cardRadius,
          side: borderColor == null ? BorderSide.none : BorderSide(color: borderColor!),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
      ),
    );
    return margin == null ? card : Padding(padding: margin!, child: card);
  }
}
