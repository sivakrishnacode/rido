import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/rido_colors.dart';
import '../theme/rido_tokens.dart';

enum RidoBannerType { info, warning, success, error }

/// Banner with icon, title, optional message and optional action.
/// Info is solid navy; the others use a 10% tint with a 1px status border and navy text.
class RidoBanner extends StatelessWidget {
  const RidoBanner({
    super.key,
    required this.type,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.icon,
    this.onTap,
    this.inlineAction = false,
  });

  final RidoBannerType type;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? icon;

  /// Makes the whole banner tappable (e.g. "Trip in progress" reopens the trip).
  final VoidCallback? onTap;

  /// Put the action as a text link on the right instead of a button below.
  final bool inlineAction;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final (Color bg, Color border, Color iconColor, Color fg, IconData defaultIcon) = switch (type) {
      RidoBannerType.info => (RidoColors.navy900, RidoColors.navy900, Colors.white, Colors.white, Symbols.info_rounded),
      RidoBannerType.warning => (
          RidoColors.warningTint,
          RidoColors.warning,
          RidoColors.warning,
          RidoColors.navy900,
          Symbols.warning_rounded
        ),
      RidoBannerType.success => (
          RidoColors.successTint,
          RidoColors.success,
          RidoColors.success,
          RidoColors.navy900,
          Symbols.check_circle_rounded
        ),
      RidoBannerType.error => (
          RidoColors.errorTint,
          RidoColors.error,
          RidoColors.error,
          RidoColors.navy900,
          Symbols.error_rounded
        ),
    };
    final actionColor = type == RidoBannerType.info ? RidoColors.coral100 : RidoColors.coral600;

    Widget? action;
    if (actionLabel != null && onAction != null) {
      action = inlineAction
          ? TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(foregroundColor: type == RidoBannerType.error ? RidoColors.error : actionColor),
              child: Text(actionLabel!),
            )
          : Padding(
              padding: const EdgeInsets.only(top: 10),
              child: FilledButton(
                onPressed: onAction,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(48, 40),
                  backgroundColor: type == RidoBannerType.error ? RidoColors.error : RidoColors.coral600,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  textStyle: t.bodySmallMedium.copyWith(fontWeight: FontWeight.w600),
                ),
                child: Text(actionLabel!),
              ),
            );
    }

    return Material(
      color: bg,
      shape: RoundedRectangleBorder(borderRadius: RidoRadii.cardRadius, side: BorderSide(color: border)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(icon ?? defaultIcon, color: iconColor, fill: 1, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: t.bodySemibold.copyWith(color: fg, fontSize: 15)),
                    if (message != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(message!,
                            style: t.bodySmall.copyWith(color: type == RidoBannerType.info ? Colors.white70 : RidoColors.navy700)),
                      ),
                    if (action != null && !inlineAction) action,
                  ],
                ),
              ),
              if (action != null && inlineAction) action,
              if (onTap != null && action == null)
                Icon(Symbols.chevron_right_rounded, color: fg),
            ],
          ),
        ),
      ),
    );
  }
}
