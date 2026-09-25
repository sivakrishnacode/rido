import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/rido_colors.dart';
import '../theme/rido_tokens.dart';
import 'rido_button.dart';

/// Floating navy snackbar (replaces the current one).
void showRidoSnack(BuildContext context, String message, {String? actionLabel, VoidCallback? onAction, bool success = false}) {
  final m = ScaffoldMessenger.maybeOf(context);
  if (m == null) return;
  m
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 3),
        content: Row(
          children: [
            if (success) ...[
              const Icon(Symbols.check_circle_rounded, color: RidoColors.success, fill: 1, size: 20),
              const SizedBox(width: 10),
            ],
            Expanded(child: Text(message)),
          ],
        ),
        action: actionLabel == null ? null : SnackBarAction(label: actionLabel, onPressed: onAction ?? () {}),
      ),
    );
}

/// Stacked-action confirmation dialog (DS-05: 16px radius, navy scrim).
/// Returns true when the primary action is chosen.
Future<bool> showRidoConfirm(
  BuildContext context, {
  required String title,
  String? message,
  required String confirmLabel,
  String cancelLabel = 'Not now',
  bool destructive = false,
  IconData? icon,
  Widget? content,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => RidoDialog(
      title: title,
      message: message,
      icon: icon,
      destructive: destructive,
      content: content,
      actions: [
        RidoButton(
          label: confirmLabel,
          variant: destructive ? RidoButtonVariant.danger : RidoButtonVariant.primary,
          onPressed: () => Navigator.of(ctx).pop(true),
        ),
        const SizedBox(height: 4),
        RidoButton.text(
          label: cancelLabel,
          expand: true,
          onPressed: () => Navigator.of(ctx).pop(false),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// The Rido dialog body: optional icon circle, title, message, custom content, stacked actions.
class RidoDialog extends StatelessWidget {
  const RidoDialog({
    super.key,
    required this.title,
    this.message,
    this.icon,
    this.destructive = false,
    this.content,
    required this.actions,
    this.tone,
  });

  final String title;
  final String? message;
  final IconData? icon;
  final bool destructive;
  final Widget? content;
  final List<Widget> actions;

  /// Overrides the icon circle colour (amber for S-14).
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final c = tone ?? (destructive ? RidoColors.error : RidoColors.coral600);
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (icon != null) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: c.withValues(alpha: 0.12), shape: BoxShape.circle),
                  child: Icon(icon, color: c, fill: 1),
                ),
              ),
              const SizedBox(height: 14),
            ],
            Text(title, style: t.h2),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(message!, style: t.bodySmall),
            ],
            if (content != null) ...[const SizedBox(height: 12), content!],
            const SizedBox(height: 18),
            ...actions,
          ],
        ),
      ),
    );
  }
}
