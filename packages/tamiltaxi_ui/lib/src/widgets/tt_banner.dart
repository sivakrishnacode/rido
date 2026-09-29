import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/tt_colors.dart';
import '../theme/tt_tokens.dart';

enum TtBannerType { info, warning, success, error }

/// Banner with icon, title, optional message and optional action.
/// Info is solid navy; the others use a 10% tint with a 1px status border and navy text.
class TtBanner extends StatelessWidget {
  const TtBanner({
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

  final TtBannerType type;
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
      TtBannerType.info => (TtColors.navy900, TtColors.navy900, Colors.white, Colors.white, Symbols.info_rounded),
      TtBannerType.warning => (
          TtColors.warningTint,
          TtColors.warning,
          TtColors.warning,
          TtColors.navy900,
          Symbols.warning_rounded
        ),
      TtBannerType.success => (
          TtColors.successTint,
          TtColors.success,
          TtColors.success,
          TtColors.navy900,
          Symbols.check_circle_rounded
        ),
      TtBannerType.error => (
          TtColors.errorTint,
          TtColors.error,
          TtColors.error,
          TtColors.navy900,
          Symbols.error_rounded
        ),
    };
    final actionColor = type == TtBannerType.info ? TtColors.coral100 : TtColors.coral600;

    Widget? action;
    if (actionLabel != null && onAction != null) {
      action = inlineAction
          ? TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(foregroundColor: type == TtBannerType.error ? TtColors.error : actionColor),
              child: Text(actionLabel!),
            )
          : Padding(
              padding: const EdgeInsets.only(top: 10),
              child: FilledButton(
                onPressed: onAction,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(48, 40),
                  backgroundColor: type == TtBannerType.error ? TtColors.error : TtColors.coral600,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  textStyle: t.bodySmallMedium.copyWith(fontWeight: FontWeight.w600),
                ),
                child: Text(actionLabel!),
              ),
            );
    }

    return Material(
      color: bg,
      shape: RoundedRectangleBorder(borderRadius: TtRadii.cardRadius, side: BorderSide(color: border)),
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
                            style: t.bodySmall.copyWith(color: type == TtBannerType.info ? Colors.white70 : TtColors.navy700)),
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
