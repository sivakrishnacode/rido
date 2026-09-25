import 'package:flutter/material.dart';

import '../theme/rido_colors.dart';
import '../theme/rido_tokens.dart';

enum RidoButtonVariant {
  /// Coral-600 fill, white text.
  primary,

  /// Navy-900 outline.
  secondary,

  /// Navy-900 fill (driver app "Go online").
  dark,

  /// Coral text, no background.
  text,

  /// Error-red fill ("Cancel ride").
  danger,

  /// Error-red text, no background ("Cancel plan").
  dangerText,
}

/// The Rido button: 52px tall, full-round. Disabled when [onPressed] is null;
/// [loading] shows a spinner, keeps the label and ignores taps.
class RidoButton extends StatelessWidget {
  const RidoButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = RidoButtonVariant.primary,
    this.icon,
    this.loading = false,
    this.expand = true,
    this.height = 52,
    this.semanticLabel,
  });

  const RidoButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = true,
    this.height = 52,
    this.semanticLabel,
  }) : variant = RidoButtonVariant.secondary;

  const RidoButton.text({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = false,
    this.height = 48,
    this.semanticLabel,
  }) : variant = RidoButtonVariant.text;

  const RidoButton.danger({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = true,
    this.height = 52,
    this.semanticLabel,
  }) : variant = RidoButtonVariant.danger;

  final String label;
  final VoidCallback? onPressed;
  final RidoButtonVariant variant;
  final IconData? icon;
  final bool loading;
  final bool expand;
  final double height;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final enabled = onPressed != null && !loading;
    final (Color bg, Color fg, BorderSide? side) = switch (variant) {
      RidoButtonVariant.primary => (RidoColors.coral600, Colors.white, null),
      RidoButtonVariant.secondary => (Colors.transparent, RidoColors.navy900,
          const BorderSide(color: RidoColors.navy900, width: 1.5)),
      RidoButtonVariant.dark => (RidoColors.navy900, Colors.white, null),
      RidoButtonVariant.text => (Colors.transparent, RidoColors.coral600, null),
      RidoButtonVariant.danger => (RidoColors.error, Colors.white, null),
      RidoButtonVariant.dangerText => (Colors.transparent, RidoColors.error, null),
    };
    final isFilled = variant == RidoButtonVariant.primary ||
        variant == RidoButtonVariant.dark ||
        variant == RidoButtonVariant.danger;
    final disabledLook = onPressed == null && !loading;
    final effectiveBg = disabledLook && isFilled ? RidoColors.divider : bg;
    final effectiveFg = disabledLook ? RidoColors.navy500 : fg;
    final effectiveSide =
        disabledLook && side != null ? const BorderSide(color: RidoColors.divider, width: 1.5) : side;

    final child = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading) ...[
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.4, color: effectiveFg, backgroundColor: Colors.transparent),
          ),
          const SizedBox(width: 12),
        ] else if (icon != null) ...[
          Icon(icon, size: 22, color: effectiveFg),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.button.copyWith(color: effectiveFg),
          ),
        ),
      ],
    );

    final button = Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel,
      child: Material(
        color: effectiveBg,
        shape: StadiumBorder(side: effectiveSide ?? BorderSide.none),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: height, minWidth: 48),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: variant == RidoButtonVariant.text ? 12 : 20),
              child: Center(widthFactor: expand ? null : 1, child: child),
            ),
          ),
        ),
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}
