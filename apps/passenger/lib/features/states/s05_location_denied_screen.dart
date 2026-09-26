import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

import '../../common/device_location.dart';
import '../../router/routes.dart';

/// S-05 Location permission denied: "Location is off" with "Open settings".
class S05LocationDeniedScreen extends StatelessWidget {
  const S05LocationDeniedScreen({super.key, this.showcase = false});

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  @override
  Widget build(BuildContext context) => const Scaffold(
    backgroundColor: RidoColors.surface,
    body: SafeArea(child: S05LocationDeniedView()),
  );
}

/// The S-05 body, also embedded by P-07 Home when Demo control "Location denied" is on.
///
/// "Open settings" simulates the user turning location on: it clears the demo switch so
/// the app recovers, then returns to Home. "Enter location manually" opens search.
class S05LocationDeniedView extends ConsumerWidget {
  const S05LocationDeniedView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.type;
    return LayoutBuilder(
      builder: (context, c) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: c.maxHeight.isFinite ? c.maxHeight : 0),
          child: IntrinsicHeight(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(RidoSpacing.l, RidoSpacing.xl, RidoSpacing.l, RidoSpacing.l),
              child: Column(
                children: [
                  const Spacer(),
                  const _LocationOffArt(size: 200),
                  const SizedBox(height: RidoSpacing.xxl),
                  Text('Location is off', style: t.display, textAlign: TextAlign.center),
                  const SizedBox(height: RidoSpacing.s),
                  Text(
                    'Rido needs your location to find nearby drivers',
                    style: t.body.copyWith(color: RidoColors.navy700),
                    textAlign: TextAlign.center,
                  ),
                  const Spacer(),
                  const SizedBox(height: RidoSpacing.xxl),
                  RidoButton(
                    label: 'Open settings',
                    onPressed: () {
                      // Live: ask again while Android still shows the prompt, else open the right settings page.
                      if (ref.read(isLiveApiProvider)) {
                        ref.read(deviceLocationProvider.notifier).fixAccess();
                      } else {
                        ref.read(deviceLocationProvider.notifier).openSettings();
                      }
                      showRidoSnack(context, 'Opening location settings');
                      ref.read(demoSettingsProvider.notifier).update((s) => s.copyWith(locationDenied: false));
                      context.go(Routes.ride);
                    },
                  ),
                  const SizedBox(height: RidoSpacing.s),
                  RidoButton.text(
                    label: 'Enter location manually',
                    expand: true,
                    onPressed: () => context.push(Routes.search),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Grey orbs with a crossed-out pin and a coral settings badge (S-05 art).
class _LocationOffArt extends StatelessWidget {
  const _LocationOffArt({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: 'Location is off',
    child: SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: const BoxDecoration(color: RidoColors.inputBg, shape: BoxShape.circle),
          ),
          Container(
            width: size * 0.7,
            height: size * 0.7,
            decoration: const BoxDecoration(color: RidoColors.divider, shape: BoxShape.circle),
          ),
          Icon(Symbols.location_off_rounded, fill: 1, size: size * 0.4, color: RidoColors.navy500),
          Positioned(
            right: size * 0.2,
            bottom: size * 0.2,
            child: Container(
              width: size * 0.22,
              height: size * 0.22,
              decoration: BoxDecoration(
                color: RidoColors.coral500,
                shape: BoxShape.circle,
                border: Border.all(color: RidoColors.surface, width: 4),
              ),
              child: Icon(Symbols.settings_rounded, size: size * 0.11, color: RidoColors.surface),
            ),
          ),
        ],
      ),
    ),
  );
}
