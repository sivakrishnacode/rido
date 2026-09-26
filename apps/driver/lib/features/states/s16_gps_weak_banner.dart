import 'package:flutter/material.dart';
import 'package:rido_ui/rido_ui.dart';

/// S-16 GPS weak / location off while online: red full-width strip under the header,
/// "GPS signal lost. Riders can't see you" with "Fix now" ([onFix]: the live app opens location settings).
class S16GpsWeakBanner extends StatelessWidget {
  const S16GpsWeakBanner({super.key, this.showcase = false, this.onFix});

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;
  final VoidCallback? onFix;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Semantics(
      liveRegion: true,
      child: Material(
        color: RidoColors.error,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(RidoSpacing.gutter, RidoSpacing.m, RidoSpacing.m, RidoSpacing.m),
          child: Row(
            children: [
              const Icon(Symbols.location_disabled_rounded, color: Colors.white, size: 28),
              const SizedBox(width: RidoSpacing.m),
              Expanded(
                child: Text("GPS signal lost. Riders can't see you",
                    style: t.bodySemibold.copyWith(color: Colors.white)),
              ),
              const SizedBox(width: RidoSpacing.s),
              FilledButton(
                onPressed: onFix ?? () => showRidoSnack(context, 'Opening location settings'),
                style: FilledButton.styleFrom(
                  backgroundColor: RidoColors.surface,
                  foregroundColor: RidoColors.error,
                  minimumSize: const Size(48, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  textStyle: t.bodySemibold,
                ),
                child: const Text('Fix now'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
