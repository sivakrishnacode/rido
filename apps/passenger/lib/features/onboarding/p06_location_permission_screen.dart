import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

import '../../common/device_location.dart';
import '../../router/routes.dart';

/// P-06 Location permission: map-pin illustration, "Allow" and "Enter location manually".
class P06LocationPermissionScreen extends ConsumerWidget {
  const P06LocationPermissionScreen({super.key, this.showcase = false});

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.type;
    return Scaffold(
      backgroundColor: RidoColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: c.maxHeight),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: RidoSpacing.xl, vertical: RidoSpacing.xl),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const _PinIllustration(size: 240),
                          const SizedBox(height: RidoSpacing.xxl),
                          Text('Allow location access', style: t.display, textAlign: TextAlign.center),
                          const SizedBox(height: RidoSpacing.m),
                          Text(
                            'So your driver finds you at the exact spot — even in busy Gandhipuram.',
                            style: t.body.copyWith(color: RidoColors.navy700),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(RidoSpacing.l, RidoSpacing.s, RidoSpacing.l, RidoSpacing.l),
              child: Column(
                children: [
                  RidoButton(
                    label: 'Allow',
                    onPressed: () async {
                      // Real Android permission prompt + GPS fix (see lib/common/device_location.dart).
                      final r = await ref.read(deviceLocationProvider.notifier).locate();
                      if (!context.mounted) return;
                      if (r == LocateResult.denied) {
                        context.go(Routes.locationDenied);
                        return;
                      }
                      if (r == LocateResult.outsideArea) {
                        showRidoSnack(
                          context,
                          ref.read(isLiveApiProvider)
                              ? "Rido isn't in your area yet. Choose a pickup in Coimbatore."
                              : "You're outside Coimbatore, so the demo uses Gandhipuram as pickup.",
                        );
                      }
                      context.go(Routes.ride);
                    },
                  ),
                  const SizedBox(height: RidoSpacing.s),
                  RidoButton.text(
                    label: 'Enter location manually',
                    expand: true,
                    onPressed: () => context.go(Routes.ride),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Coral pin on two soft orbs with a small ground shadow.
class _PinIllustration extends StatelessWidget {
  const _PinIllustration({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: 'A map pin',
    child: SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: const BoxDecoration(color: RidoColors.coral50, shape: BoxShape.circle),
          ),
          Container(
            width: size * 0.7,
            height: size * 0.7,
            decoration: const BoxDecoration(color: RidoColors.coral100, shape: BoxShape.circle),
          ),
          Positioned(
            bottom: size * 0.26,
            child: Container(
              width: size * 0.3,
              height: size * 0.07,
              decoration: BoxDecoration(
                color: RidoColors.navy900.withValues(alpha: 0.12),
                borderRadius: const BorderRadius.all(Radius.elliptical(100, 40)),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(bottom: size * 0.1),
            child: Icon(Symbols.location_on_rounded, fill: 1, size: size * 0.42, color: RidoColors.coral500),
          ),
        ],
      ),
    ),
  );
}
