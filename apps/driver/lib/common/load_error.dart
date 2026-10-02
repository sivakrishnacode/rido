import 'package:flutter/material.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';
import 'package:tamiltaxi_ui/tamiltaxi_ui.dart';

import '../state/live_helpers.dart';

/// Something a screen needs didn't load (live API): offline, or the API's message, with Retry. Screens show this
/// instead of seed data, so nothing made-up is shown or saved over the real driver.
class LoadError extends StatelessWidget {
  const LoadError({super.key, required this.error, required this.onRetry, this.what = 'this'});

  final Object error;
  final VoidCallback onRetry;

  /// "your profile", "your plan"… for the title when it isn't an offline error.
  final String what;

  @override
  Widget build(BuildContext context) {
    final offline = error is OfflineException;
    return EmptyState(
      illustration: const TtIllustration(IllustrationKind.offline, height: 140),
      title: offline ? "You're offline" : "Couldn't load $what",
      message: offline ? 'Check your internet connection and try again.' : userMessage(error),
      actionLabel: 'Retry',
      onAction: onRetry,
    );
  }
}
