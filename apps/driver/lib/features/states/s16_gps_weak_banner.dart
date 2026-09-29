import 'package:flutter/material.dart';
import 'package:tamiltaxi_ui/tamiltaxi_ui.dart';

/// S-16 GPS weak / location off while online: red full-width strip under the header,
/// "GPS signal lost. Riders can't see you" with "Fix now" ([onFix]: the live app restarts GPS, or opens location settings when it's off).
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
        color: TtColors.error,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(TtSpacing.gutter, TtSpacing.m, TtSpacing.m, TtSpacing.m),
          child: Row(
            children: [
              const Icon(Symbols.location_disabled_rounded, color: Colors.white, size: 28),
              const SizedBox(width: TtSpacing.m),
              Expanded(
                child: Text("GPS signal lost. Riders can't see you",
                    style: t.bodySemibold.copyWith(color: Colors.white)),
              ),
              const SizedBox(width: TtSpacing.s),
              FilledButton(
                onPressed: onFix ?? () => showTtSnack(context, 'Opening location settings'),
                style: FilledButton.styleFrom(
                  backgroundColor: TtColors.surface,
                  foregroundColor: TtColors.error,
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
