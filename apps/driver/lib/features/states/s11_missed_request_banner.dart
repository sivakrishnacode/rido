import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rido_ui/rido_ui.dart';

import '../../state/driver_session.dart';

/// S-11 Missed ride request: navy toast "You missed a ride request. Stay alert to get more
/// rides." with OK. Shown on D-14 after a request times out (the gallery shows it through
/// `D13HomeScreen(variant: HomeVariant.missedRequest)`).
class S11MissedRequestBanner extends ConsumerWidget {
  const S11MissedRequestBanner({super.key, this.showcase = false, this.onDismiss, this.delivery = false});

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  /// Called on OK; defaults to clearing the session's missed-request flag.
  final VoidCallback? onDismiss;

  /// Says "delivery request" for delivery drivers.
  final bool delivery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.type;
    final kind = delivery ? 'delivery' : 'ride';
    return Semantics(
      liveRegion: true,
      child: Material(
        color: RidoColors.navy900,
        borderRadius: RidoRadii.cardRadius,
        elevation: 6,
        shadowColor: RidoColors.shadow,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(RidoSpacing.l, RidoSpacing.m, RidoSpacing.s, RidoSpacing.m),
          child: Row(
            children: [
              const Icon(Symbols.notifications_paused_rounded, color: RidoColors.warning, fill: 1, size: 26),
              const SizedBox(width: RidoSpacing.m),
              Expanded(
                child: Text(
                  'You missed a $kind request. Stay alert to get more ${kind}s.',
                  style: t.body.copyWith(color: Colors.white),
                ),
              ),
              TextButton(
                onPressed: onDismiss ?? () => ref.read(driverSessionProvider.notifier).dismissMissedBanner(),
                style: TextButton.styleFrom(foregroundColor: RidoColors.coral100),
                child: const Text('OK'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
