import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

import '../../../state/driver_session.dart';

/// [RidoMap] showing the driver's own vehicle. The marker follows the session's live
/// position unless [fixedPosition] is given (gallery showcase).
class LiveVehicleMap extends ConsumerWidget {
  const LiveVehicleMap({
    super.key,
    required this.vehicleType,
    this.fixedPosition,
    this.pickup,
    this.drop,
    this.route = const [],
    this.fitPoints,
    this.fitPadding = const EdgeInsets.fromLTRB(48, 96, 48, 48),
    this.pulse = false,
    this.zones = const [],
    this.zoom = 14.5,
    this.gpsLost = false,
    this.centerOnVehicle = true,
    this.mapPadding = EdgeInsets.zero,
  });

  final MapVehicleType vehicleType;
  final LatLng? fixedPosition;
  final LatLng? pickup;
  final LatLng? drop;
  final List<LatLng> route;
  final List<LatLng>? fitPoints;
  final EdgeInsets fitPadding;

  /// Green pulse ring around the vehicle (online, waiting for rides).
  final bool pulse;
  final List<MapZone> zones;
  final double zoom;

  /// S-16: draw a dashed red "location lost" circle instead of the vehicle.
  final bool gpsLost;
  final bool centerOnVehicle;

  /// Google engine: keeps the logo clear of panels drawn over the map (Maps terms).
  final EdgeInsets mapPadding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (fixedPosition != null) return _map(fixedPosition!, 0);
    final notifier = ref.read(driverSessionProvider.notifier);
    return ValueListenableBuilder<VehicleFix?>(
      valueListenable: notifier.vehicle,
      builder: (context, fix, _) => _map(fix?.position ?? Seed.driverHome, fix?.heading ?? 0),
    );
  }

  Widget _map(LatLng pos, double heading) => RidoMap(
        center: centerOnVehicle ? pos : null,
        zoom: zoom,
        pickup: pickup,
        drop: drop,
        route: route,
        fitPoints: fitPoints,
        fitPadding: fitPadding,
        mapPadding: mapPadding,
        pulseAt: pulse && !gpsLost ? pos : null,
        pulseColor: RidoColors.success,
        zones: zones,
        vehicles: gpsLost ? const [] : [MapVehicle(position: pos, type: vehicleType, heading: heading, large: true)],
        extraMarkers: [
          if (gpsLost) Marker(point: pos, width: 128, height: 128, child: const _GpsLostMarker()),
        ],
      );
}

class _GpsLostMarker extends StatelessWidget {
  const _GpsLostMarker();

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Location lost',
        child: CustomPaint(
          painter: _DashedCirclePainter(),
          child: Center(
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(color: RidoColors.surface, shape: BoxShape.circle, boxShadow: RidoShadows.soft),
              child: const Icon(Symbols.location_disabled_rounded, color: RidoColors.error, size: 24),
            ),
          ),
        ),
      );
}

class _DashedCirclePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 2;
    canvas.drawCircle(c, r, Paint()..color = RidoColors.error.withValues(alpha: 0.08));
    final stroke = Paint()
      ..color = RidoColors.error
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    const dashes = 28;
    const sweep = 2 * math.pi / dashes;
    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(Rect.fromCircle(center: c, radius: r), i * sweep, sweep * 0.55, false, stroke);
    }
  }

  @override
  bool shouldRepaint(covariant _DashedCirclePainter oldDelegate) => false;
}

/// Demand zones from the seed. [labelled] names get a chip; the first can say "High demand: …".
List<MapZone> demandZones({Set<String> labelled = const {}, bool highDemandLabel = false}) => [
      for (final z in Seed.demandZones)
        MapZone(
          centre: z.centre,
          radiusM: z.radiusM,
          label: labelled.contains(z.name) ? (highDemandLabel ? 'High demand: ${z.name}' : z.name) : null,
        ),
    ];
