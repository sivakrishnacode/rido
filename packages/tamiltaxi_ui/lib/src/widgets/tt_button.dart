import 'package:flutter/material.dart';

import '../theme/tt_colors.dart';
import '../theme/tt_tokens.dart';

enum TtButtonVariant {
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

/// The Tamil Taxi button: 52px tall, full-round. Disabled when [onPressed] is null;
/// [loading] shows a spinner, keeps the label and ignores taps.
class TtButton extends StatelessWidget {
  const TtButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = TtButtonVariant.primary,
    this.icon,
    this.loading = false,
    this.expand = true,
    this.height = 52,
    this.semanticLabel,
  });

  const TtButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = true,
    this.height = 52,
    this.semanticLabel,
  }) : variant = TtButtonVariant.secondary;

  const TtButton.text({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = false,
    this.height = 48,
    this.semanticLabel,
  }) : variant = TtButtonVariant.text;

  const TtButton.danger({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = true,
    this.height = 52,
    this.semanticLabel,
  }) : variant = TtButtonVariant.danger;

  final String label;
  final VoidCallback? onPressed;
  final TtButtonVariant variant;
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
      TtButtonVariant.primary => (TtColors.coral600, Colors.white, null),
      TtButtonVariant.secondary => (Colors.transparent, TtColors.navy900,
          const BorderSide(color: TtColors.navy900, width: 1.5)),
      TtButtonVariant.dark => (TtColors.navy900, Colors.white, null),
      TtButtonVariant.text => (Colors.transparent, TtColors.coral600, null),
      TtButtonVariant.danger => (TtColors.error, Colors.white, null),
      TtButtonVariant.dangerText => (Colors.transparent, TtColors.error, null),
    };
    final isFilled = variant == TtButtonVariant.primary ||
        variant == TtButtonVariant.dark ||
        variant == TtButtonVariant.danger;
    final disabledLook = onPressed == null && !loading;
    final effectiveBg = disabledLook && isFilled ? TtColors.divider : bg;
    final effectiveFg = disabledLook ? TtColors.navy500 : fg;
    final effectiveSide =
        disabledLook && side != null ? const BorderSide(color: TtColors.divider, width: 1.5) : side;

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
              padding: EdgeInsets.symmetric(horizontal: variant == TtButtonVariant.text ? 12 : 20),
              child: Center(widthFactor: expand ? null : 1, child: child),
            ),
          ),
        ),
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}
