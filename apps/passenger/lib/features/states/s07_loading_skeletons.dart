import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' show Marker;
import 'package:go_router/go_router.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

import '../../common/passenger_shell.dart';
import '../../router/routes.dart';

/// S-07a Home skeleton: the P-07 map and bottom sheet while Home data loads.
class S07aHomeSkeletonScreen extends StatelessWidget {
  const S07aHomeSkeletonScreen({super.key, this.showcase = false});

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  static const _tabs = [Routes.ride, Routes.parcel, Routes.activity, Routes.account];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RidoColors.surface,
      body: LayoutBuilder(
        builder: (context, c) {
          final sheetTop = c.maxHeight * 0.4;
          return Stack(
            children: [
              Positioned.fill(
                bottom: c.maxHeight - sheetTop - RidoSpacing.xl,
                child: Stack(
                  children: [
                    RidoMap(
                      center: offsetPoint(Seed.gandhipuram.location, 250, 180),
                      zoom: 15,
                      interactive: false,
                      showAttribution: false,
                      extraMarkers: [
                        Marker(
                          point: Seed.gandhipuram.location,
                          width: 24,
                          height: 24,
                          child: Container(
                            decoration: BoxDecoration(
                              color: RidoColors.navy300,
                              shape: BoxShape.circle,
                              border: Border.all(color: RidoColors.surface, width: 4),
                            ),
                          ),
                        ),
                      ],
                    ),
                    // Wash the map out while loading.
                    Positioned.fill(child: ColoredBox(color: RidoColors.surface.withValues(alpha: 0.45))),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(RidoSpacing.l, RidoSpacing.m, RidoSpacing.l, 0),
                    child: SkeletonShimmer(
                      child: Container(
                        height: 56,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: const BoxDecoration(
                          color: RidoColors.surface,
                          borderRadius: RidoRadii.pillRadius,
                          boxShadow: RidoShadows.soft,
                        ),
                        child: const Row(
                          children: [
                            SkeletonBox(width: 44, height: 44, circle: true),
                            SizedBox(width: RidoSpacing.m),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SkeletonBox(width: 90, height: 10),
                                SizedBox(height: RidoSpacing.s),
                                SkeletonBox(width: 60, height: 10),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: sheetTop,
                bottom: 0,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    color: RidoColors.surface,
                    borderRadius: RidoRadii.sheetTop,
                    boxShadow: RidoShadows.raised,
                  ),
                  child: SingleChildScrollView(
                    physics: NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(RidoSpacing.l, 0, RidoSpacing.l, RidoSpacing.l),
                    child: Column(children: [SheetHandle(), S07aHomeSheetSkeleton()]),
                  ),
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: RidoBottomNav(
        items: PassengerShell.items,
        currentIndex: 0,
        onTap: (i) => context.go(_tabs[i]),
      ),
    );
  }
}

/// The Home bottom-sheet content in skeleton form (search, saved places, 2 recent rows, promo).
/// P-07 shows it while recent destinations load.
class S07aHomeSheetSkeleton extends StatelessWidget {
  const S07aHomeSheetSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    Widget row() => const Padding(
      padding: EdgeInsets.symmetric(vertical: RidoSpacing.m),
      child: Row(
        children: [
          SkeletonBox(width: 40, height: 40, circle: true),
          SizedBox(width: RidoSpacing.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FractionallySizedBox(widthFactor: 0.6, child: SkeletonBox(height: 12)),
                SizedBox(height: RidoSpacing.s),
                FractionallySizedBox(widthFactor: 0.4, child: SkeletonBox(height: 10)),
              ],
            ),
          ),
        ],
      ),
    );
    return SkeletonShimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SkeletonBox(height: 56, radius: RidoRadii.card),
          const SizedBox(height: RidoSpacing.l),
          const Row(
            children: [
              Expanded(flex: 2, child: SkeletonBox(height: 56, radius: RidoRadii.card)),
              SizedBox(width: RidoSpacing.s),
              Expanded(flex: 2, child: SkeletonBox(height: 56, radius: RidoRadii.card)),
              SizedBox(width: RidoSpacing.s),
              Expanded(child: SkeletonBox(height: 56, radius: RidoRadii.card)),
            ],
          ),
          const SizedBox(height: RidoSpacing.s),
          row(),
          row(),
          const SizedBox(height: RidoSpacing.s),
          const SkeletonBox(height: 72, radius: RidoRadii.card),
        ],
      ),
    );
  }
}
