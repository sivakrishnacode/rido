import 'package:flutter/material.dart';

import '../theme/rido_colors.dart';
import '../theme/rido_tokens.dart';

/// White card with a 1px divider border and 12px radius. Tappable when [onTap] is set.
class RidoCard extends StatelessWidget {
  const RidoCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.color = RidoColors.surface,
    this.borderColor = RidoColors.divider,
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
      decoration: BoxDecoration(borderRadius: RidoRadii.cardRadius, boxShadow: shadow ? RidoShadows.soft : null),
      child: Material(
        color: color,
        shape: RoundedRectangleBorder(
          borderRadius: RidoRadii.cardRadius,
          side: borderColor == null ? BorderSide.none : BorderSide(color: borderColor!),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
      ),
    );
    return margin == null ? card : Padding(padding: margin!, child: card);
  }
}
