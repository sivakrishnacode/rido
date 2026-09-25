import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' show Marker;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

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
    ref.read(rideFlowProvider.notifier).cancelSearch();
    context.go(Routes.ride);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.type;
    final ride = ref.watch(rideFlowProvider);
    // Suggest Auto for bikes, Cab for autos, Auto for cabs.
    final alt = ride.vehicle == VehicleKind.auto ? VehicleKind.cab : VehicleKind.auto;
    final altQuote = ride.quotes.firstWhere((q) => q.vehicle.kind == alt);
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
        map: (context, h) => RidoMap(
          pickup: ride.pickup.location,
          fitPoints: [offsetPoint(ride.pickup.location, 700, 0), offsetPoint(ride.pickup.location, 700, 180)],
          fitPadding: EdgeInsets.fromLTRB(24, 72, 24, h * 0.5),
          attributionAlignment: Alignment.topRight,
          extraMarkers: [
            Marker(
              point: ride.pickup.location,
              width: 240,
              height: 240,
              child: const IgnorePointer(child: CustomPaint(painter: _SearchRingPainter())),
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
                child: Icon(ride.vehicle.icon, fill: 1, size: 64, color: RidoColors.coral500),
              ),
            ),
            const SizedBox(height: 16),
            Text('No $plural nearby right now', style: t.h1, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(
              'Try ${others.join(' or ')}, or try again in a few minutes',
              style: t.body.copyWith(color: RidoColors.navy700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            RidoButton(
              label: 'Try ${alt.label} · ${formatInr(altQuote.total)}',
              icon: alt.icon,
              onPressed: () {
                ref.read(rideFlowProvider.notifier).retryWith(alt);
                context.go(Routes.findingDriver);
              },
            ),
            const SizedBox(height: 10),
            RidoButton.secondary(
              label: 'Retry',
              onPressed: () {
                ref.read(rideFlowProvider.notifier).book();
                context.go(Routes.findingDriver);
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Dashed navy outer ring + faint inner ring: the "empty search area".
class _SearchRingPainter extends CustomPainter {
  const _SearchRingPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 2;
    canvas.drawCircle(c, r, Paint()..color = RidoColors.navy500.withValues(alpha: 0.08));
    _dashed(canvas, c, r, RidoColors.navy500, 2.4, 40);
    _dashed(canvas, c, r * 0.5, RidoColors.navy300, 2, 22);
  }

  void _dashed(Canvas canvas, Offset c, double r, Color color, double width, int dashes) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;
    const full = 6.283185307179586;
    final step = full / dashes;
    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(Rect.fromCircle(center: c, radius: r), i * step, step * 0.55, false, p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
