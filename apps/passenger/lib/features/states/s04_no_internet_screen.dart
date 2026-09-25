import 'package:flutter/material.dart';
import 'package:rido_ui/rido_ui.dart';

/// S-04 No internet: "You're offline", with a full-width Retry at the bottom.
class S04NoInternetScreen extends StatelessWidget {
  const S04NoInternetScreen({super.key, this.onRetry, this.showcase = false});

  final VoidCallback? onRetry;

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: RidoColors.surface,
        body: SafeArea(
          child: S04NoInternetView(
            onRetry: onRetry ?? () => showRidoSnack(context, 'Still offline. Check your connection.'),
          ),
        ),
      );
}

/// The S-04 body, embedded by data screens when a repository reports [OfflineException].
class S04NoInternetView extends StatefulWidget {
  const S04NoInternetView({super.key, this.onRetry});
  final VoidCallback? onRetry;

  @override
  State<S04NoInternetView> createState() => _S04NoInternetViewState();
}

class _S04NoInternetViewState extends State<S04NoInternetView> {
  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return LayoutBuilder(
      builder: (context, c) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: c.maxHeight.isFinite ? c.maxHeight : 0),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
            child: Column(
              children: [
                const SizedBox(height: 48),
                const RidoIllustration(IllustrationKind.offline, width: 200, height: 200),
                const SizedBox(height: 28),
                Text("You're offline", style: t.display, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text('Check your connection and try again',
                    style: t.body.copyWith(color: RidoColors.navy700), textAlign: TextAlign.center),
                const SizedBox(height: 48),
                RidoButton(
                  label: 'Retry',
                  icon: Symbols.refresh_rounded,
                  onPressed: widget.onRetry ?? () => showRidoSnack(context, 'Still offline. Check your connection.'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
