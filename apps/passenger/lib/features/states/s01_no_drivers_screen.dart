import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';
import 'package:tamiltaxi_ui/tamiltaxi_ui.dart';

import '../../common/map_insets.dart';
import '../../router/routes.dart';
import '../../state/ride_flow.dart';
import '../ride/widgets/trip_widgets.dart';
import 'widgets/state_orb.dart';

/// S-01 No drivers nearby: an empty dashed search ring on the map, "No bikes nearby right now",
/// "Try Auto · ₹72" (re-books with another vehicle) and "Retry".
class S01NoDriversScreen extends ConsumerWidget {
  const S01NoDriversScreen({super.key, this.showcase = false});

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  void _back(BuildContext context, WidgetRef ref) {
    if (showcase) {
      Navigator.of(context).maybePop();
      return;
    }
    // The search already ended: nothing to cancel on the server.
    unawaited(ref.read(rideFlowProvider.notifier).cancelSearch());
    context.go(Routes.ride);
  }

  /// Books again (a new request when live); stays here with the reason if the server refuses.
  Future<void> _rebook(BuildContext context, WidgetRef ref, {VehicleKind? vehicle}) async {
    final flow = ref.read(rideFlowProvider.notifier);
    final error = vehicle == null ? await flow.book() : await flow.retryWith(vehicle);
    if (!context.mounted) return;
    if (error != null) {
      showTtSnack(context, error);
      return;
    }
    context.go(Routes.findingDriver);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.type;
    final ride = ref.watch(rideFlowProvider);
    // Suggest Auto for bikes, Cab for autos, Auto for cabs.
    final alt = ride.vehicle == VehicleKind.auto ? VehicleKind.cab : VehicleKind.auto;
    final altQuote = ride.quotes.firstWhere((q) => q.vehicle.kind == alt, orElse: () => ride.quote);
    final plural = switch (ride.vehicle) {
      VehicleKind.bike => 'bikes',
      VehicleKind.auto => 'autos',
      VehicleKind.cab => 'cabs',
      _ => 'drivers',
    };
    final others = [for (final v in [VehicleKind.bike, VehicleKind.auto, VehicleKind.cab]) if (v != ride.vehicle) v.label];

    return PopScope(
      canPop: showcase,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back(context, ref);
      },
      child: TripSheetScaffold(
        map: (context, h) => TtMap(
          pickup: ride.pickup.location,
          fitPoints: hexDiskOutline(ride.pickup.location, HexRes.r8, 1),
          fitPadding: sheetMapInsets(EdgeInsets.fromLTRB(24, 72, 24, h * 0.5), h * 0.5).fit,
          mapPadding: sheetMapInsets(EdgeInsets.fromLTRB(24, 72, 24, h * 0.5), h * 0.5).map,
          attributionAlignment: Alignment.topRight,
          attributionPadding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
          // The empty search area as dispatch sees it: the pickup's hex and the ring around it.
          polygons: [
            for (final cell in hexDiskCells(ride.pickup.location, HexRes.r8, 1))
              MapPolygon(
                points: cell,
                fillColor: TtColors.navy500.withValues(alpha: 0.07),
                strokeColor: TtColors.navy500.withValues(alpha: 0.35),
                strokeWidth: 1.5,
              ),
          ],
        ),
        overlays: [TripMapTopBar(onBack: () => _back(context, ref))],
        sheet: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 4),
            Center(
              child: StateOrb(
                size: 120,
                badge: Symbols.search_off_rounded,
                label: 'No drivers nearby',
                child: Icon(ride.vehicle.icon, fill: 1, size: 64, color: TtColors.coral500),
              ),
            ),
            const SizedBox(height: 16),
            Text('No $plural nearby right now', style: t.h1, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(
              'Try ${others.join(' or ')}, or try again in a few minutes',
              style: t.body.copyWith(color: TtColors.navy700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TtButton(
              label: 'Try ${alt.label} · ${formatInr(altQuote.total)}',
              icon: alt.icon,
              loading: ride.busy,
              onPressed: ride.busy ? null : () => _rebook(context, ref, vehicle: alt),
            ),
            const SizedBox(height: 10),
            TtButton.secondary(
              label: 'Retry',
              onPressed: ride.busy ? null : () => _rebook(context, ref),
            ),
          ],
        ),
      ),
    );
  }
}
