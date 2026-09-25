import 'package:flutter/material.dart';

import '../theme/rido_colors.dart';
import '../theme/rido_tokens.dart';
import 'rido_button.dart';

/// Empty / error state: illustration, title, one line of explanation, one clear action.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.illustration,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
    this.loading = false,
  });

  final Widget illustration;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  /// Shows the primary action in its loading state (e.g. "Retry" while re-checking).
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            illustration,
            const SizedBox(height: 24),
            Text(title, style: t.h1, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(message, style: t.body.copyWith(color: RidoColors.navy700), textAlign: TextAlign.center),
            if (actionLabel != null) ...[
              const SizedBox(height: 28),
              RidoButton(label: actionLabel!, onPressed: onAction, loading: loading),
            ],
            if (secondaryLabel != null) ...[
              const SizedBox(height: 8),
              RidoButton.text(label: secondaryLabel!, onPressed: onSecondary),
            ],
          ],
        ),
      ),
    );
  }
}
