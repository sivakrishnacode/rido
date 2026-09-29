import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' show Marker;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';
import 'package:tamiltaxi_ui/tamiltaxi_ui.dart';

import '../../router/routes.dart';

/// S-08 Service not available: the pin is outside Coimbatore.
class S08ServiceUnavailableScreen extends StatelessWidget {
  const S08ServiceUnavailableScreen({super.key, this.showcase = false});

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  @override
  Widget build(BuildContext context) =>
      const Scaffold(backgroundColor: TtColors.surface, body: S08ServiceUnavailableView());
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
              height: mapBottom + TtSpacing.xl,
              child: TtMap(
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
                        padding: const EdgeInsets.symmetric(horizontal: TtSpacing.m, vertical: 6),
                        decoration: const BoxDecoration(
                          color: TtColors.surface,
                          borderRadius: TtRadii.pillRadius,
                          boxShadow: TtShadows.soft,
                        ),
                        child: Text(
                          'Tamil Taxi service area',
                          style: t.bodySmallMedium.copyWith(color: TtColors.coral600, fontWeight: FontWeight.w600),
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
                          padding: const EdgeInsets.symmetric(horizontal: TtSpacing.m, vertical: TtSpacing.xs),
                          decoration: const BoxDecoration(
                            color: TtColors.navy900,
                            borderRadius: TtRadii.pillRadius,
                          ),
                          child: Text('Your pin', style: t.bodySmallMedium.copyWith(color: TtColors.surface)),
                        ),
                        const Icon(Symbols.location_on_rounded, fill: 1, size: 44, color: TtColors.navy900),
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
                  color: TtColors.surface,
                  borderRadius: TtRadii.sheetTop,
                  boxShadow: TtShadows.raised,
                ),
                child: SafeArea(
                  top: false,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(TtSpacing.l, 0, TtSpacing.l, TtSpacing.l),
                    child: Column(
                      children: [
                        const SheetHandle(),
                        Container(
                          width: 112,
                          height: 112,
                          decoration: const BoxDecoration(color: TtColors.coral50, shape: BoxShape.circle),
                          child: const Icon(Symbols.wrong_location_rounded, size: 52, color: TtColors.coral500),
                        ),
                        const SizedBox(height: TtSpacing.l),
                        Text("Tamil Taxi isn't in this area yet", style: t.h1, textAlign: TextAlign.center),
                        const SizedBox(height: TtSpacing.s),
                        Text(
                          "We're live across Coimbatore. More cities coming soon.",
                          style: t.body.copyWith(color: TtColors.navy700),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: TtSpacing.xl),
                        TtButton(
                          label: 'Change location',
                          onPressed: () {
                            ref
                                .read(demoSettingsProvider.notifier)
                                .update((s) => s.copyWith(outsideServiceArea: false));
                            showTtSnack(context, 'Choose a place inside Coimbatore');
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
