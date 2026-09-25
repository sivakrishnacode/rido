import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' show Marker;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

import '../../router/routes.dart';

/// S-08 Service not available: the pin is outside Coimbatore.
class S08ServiceUnavailableScreen extends StatelessWidget {
  const S08ServiceUnavailableScreen({super.key, this.showcase = false});

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  @override
  Widget build(BuildContext context) =>
      const Scaffold(backgroundColor: RidoColors.surface, body: S08ServiceUnavailableView());
}

/// The S-08 body (map with the service area + explanation sheet). Also embedded by P-07
/// Home when Demo control "Outside service area" is on.
///
/// "Change location" clears that demo switch, then goes back to where the pin was chosen
/// (or to Home when shown there).
class S08ServiceUnavailableView extends ConsumerWidget {
  const S08ServiceUnavailableView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.type;
    final pin = Seed.outsideArea.location;
    final southEdge = offsetPoint(Seed.cityCentre, Seed.serviceRadiusKm * 1000, 180);
    return LayoutBuilder(
      builder: (context, c) {
        const sheetMin = 330.0;
        final mapBottom = (c.maxHeight - sheetMin).clamp(160.0, c.maxHeight);
        return Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: mapBottom + RidoSpacing.xl,
              child: RidoMap(
                center: Seed.cityCentre,
                zoom: 10,
                fitPoints: [pin, southEdge],
                fitPadding: const EdgeInsets.fromLTRB(32, 72, 32, 56),
                zones: const [MapZone(centre: Seed.cityCentre, radiusM: Seed.serviceRadiusKm * 1000)],
                extraMarkers: [
                  Marker(
                    point: Seed.cityCentre,
                    width: 200,
                    height: 40,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: RidoSpacing.m, vertical: 6),
                        decoration: const BoxDecoration(
                          color: RidoColors.surface,
                          borderRadius: RidoRadii.pillRadius,
                          boxShadow: RidoShadows.soft,
                        ),
                        child: Text(
                          'Rido service area',
                          style: t.bodySmallMedium.copyWith(color: RidoColors.coral600, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                  Marker(
                    point: pin,
                    width: 120,
                    height: 100,
                    alignment: Alignment.topCenter,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: RidoSpacing.m, vertical: RidoSpacing.xs),
                          decoration: const BoxDecoration(
                            color: RidoColors.navy900,
                            borderRadius: RidoRadii.pillRadius,
                          ),
                          child: Text('Your pin', style: t.bodySmallMedium.copyWith(color: RidoColors.surface)),
                        ),
                        const Icon(Symbols.location_on_rounded, fill: 1, size: 44, color: RidoColors.navy900),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              top: mapBottom,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: RidoColors.surface,
                  borderRadius: RidoRadii.sheetTop,
                  boxShadow: RidoShadows.raised,
                ),
                child: SafeArea(
                  top: false,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(RidoSpacing.l, 0, RidoSpacing.l, RidoSpacing.l),
                    child: Column(
                      children: [
                        const SheetHandle(),
                        Container(
                          width: 112,
                          height: 112,
                          decoration: const BoxDecoration(color: RidoColors.coral50, shape: BoxShape.circle),
                          child: const Icon(Symbols.wrong_location_rounded, size: 52, color: RidoColors.coral500),
                        ),
                        const SizedBox(height: RidoSpacing.l),
                        Text("Rido isn't in this area yet", style: t.h1, textAlign: TextAlign.center),
                        const SizedBox(height: RidoSpacing.s),
                        Text(
                          "We're live across Coimbatore. More cities coming soon.",
                          style: t.body.copyWith(color: RidoColors.navy700),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: RidoSpacing.xl),
                        RidoButton(
                          label: 'Change location',
                          onPressed: () {
                            ref
                                .read(demoSettingsProvider.notifier)
                                .update((s) => s.copyWith(outsideServiceArea: false));
                            showRidoSnack(context, 'Choose a place inside Coimbatore');
                            if (context.canPop()) {
                              context.pop();
                            } else {
                              context.go(Routes.ride);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
