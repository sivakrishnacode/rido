import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;
import 'package:latlong2/latlong.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:rido_data/rido_data.dart' show isGoogleMapsEnabled;

import '../theme/rido_colors.dart';
import '../theme/rido_tokens.dart';
import '../vehicle_ui.dart';
import 'location_markers.dart';
import 'map_bitmaps.dart';
import 'map_markers.dart';
import 'rido_map_style.dart';

part 'rido_map_google.dart';

/// Engine-neutral camera snapshot passed to [RidoMap.onPositionChanged].
@immutable
class RidoCamera {
  const RidoCamera({required this.center, required this.zoom});
  final LatLng center;
  final double zoom;
}

/// Engine-neutral map controller: works with both the Google map and the flutter_map fallback.
class RidoMapController {
  final MapController _flutterMap = MapController();
  _GoogleRidoMapState? _google;

  /// Moves the camera (no animation). Does nothing if the map is not laid out yet.
  void move(LatLng center, double zoom) {
    final google = _google;
    if (google != null) {
      google._moveTo(center, zoom);
      return;
    }
    try {
      _flutterMap.move(center, zoom);
    } catch (_) {
      // Map not laid out yet.
    }
  }

  void dispose() {
    _google = null;
    _flutterMap.dispose();
  }
}

/// A vehicle drawn on the map, rotated to [heading] degrees.
class MapVehicle {
  const MapVehicle({required this.position, required this.type, this.heading = 0, this.large = false});
  final LatLng position;
  final MapVehicleType type;
  final double heading;

  /// Larger marker with a white halo (the driver's own vehicle / assigned driver).
  final bool large;
}

/// Soft coral "busy area" circle, optionally labelled.
class MapZone {
  const MapZone({required this.centre, required this.radiusM, this.label});
  final LatLng centre;
  final double radiusM;
  final String? label;
}

/// Rido map. With a Google Maps key ([isGoogleMapsEnabled]) and [tilesEnabled] it renders the
/// Google Maps SDK (styled light map, bitmap markers); otherwise flutter_map with CARTO
/// light-grey tiles and the required attribution (tests, no key).
///
/// Draws pickup (green dot), drop (coral pin), vehicles (navy top-down icons), a coral 5px
/// route, a pulse ring and demand zones. If tiles fail (offline) the plain #F1F5F9
/// background shows; nothing throws.
class RidoMap extends StatelessWidget {
  const RidoMap({
    super.key,
    this.center,
    this.zoom = 14.5,
    this.pickup,
    this.drop,
    this.route = const [],
    this.vehicles = const [],
    this.pulseAt,
    this.pulseColor = RidoColors.coral500,
    this.zones = const [],
    this.fitPoints,
    this.fitPadding = const EdgeInsets.fromLTRB(48, 96, 48, 48),
    this.interactive = true,
    this.controller,
    this.onPositionChanged,
    this.extraMarkers = const [],
    this.showAttribution = true,
    this.attributionAlignment = Alignment.bottomLeft,
    this.mapPadding = EdgeInsets.zero,
  });

  /// Global switch; tests set this to false so no network tiles are requested and no Google
  /// platform view is ever created.
  static bool tilesEnabled = true;

  /// True when this build renders the Google Maps SDK instead of flutter_map.
  static bool get usesGoogle => tilesEnabled && isGoogleMapsEnabled;

  /// CARTO basemaps key (sent as `?key=`; without it CARTO watermarks tiles "API KEY REQUIRED").
  /// Override at build time with --dart-define=CARTO_KEY=...
  static const cartoKey = String.fromEnvironment('CARTO_KEY', defaultValue: 'cb1_3wmx_1_05c6b460c2cfe8447648257d');

  static const tileUrl = 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png?key=$cartoKey';

  final LatLng? center;
  final double zoom;
  final LatLng? pickup;
  final LatLng? drop;
  final List<LatLng> route;
  final List<MapVehicle> vehicles;
  final LatLng? pulseAt;
  final Color pulseColor;
  final List<MapZone> zones;

  /// When set, the camera fits these points on first build.
  final List<LatLng>? fitPoints;
  final EdgeInsets fitPadding;
  final bool interactive;
  final RidoMapController? controller;
  final void Function(RidoCamera camera, bool hasGesture)? onPositionChanged;
  final List<Marker> extraMarkers;
  final bool showAttribution;
  final Alignment attributionAlignment;

  /// Google engine: insets for the logo / attribution and controls (`GoogleMap.padding`). Screens with a bottom
  /// sheet over the map pass the sheet height so the Google logo stays visible (required by the Maps terms).
  final EdgeInsets mapPadding;

  @override
  Widget build(BuildContext context) {
    if (usesGoogle) return _GoogleRidoMap(map: this);
    final fit = fitPoints != null && fitPoints!.length >= 2
        ? CameraFit.coordinates(coordinates: fitPoints!, padding: fitPadding, maxZoom: 16)
        : null;
    return ClipRect(
      child: FlutterMap(
        mapController: controller?._flutterMap,
        options: MapOptions(
          initialCenter: center ?? pickup ?? const LatLng(11.0168, 76.9658),
          initialZoom: zoom,
          initialCameraFit: fit,
          backgroundColor: RidoColors.inputBg,
          minZoom: 10,
          maxZoom: 18,
          onPositionChanged: onPositionChanged == null
              ? null
              : (camera, hasGesture) =>
                  onPositionChanged!(RidoCamera(center: camera.center, zoom: camera.zoom), hasGesture),
          interactionOptions: InteractionOptions(
            flags: interactive ? InteractiveFlag.all & ~InteractiveFlag.rotate : InteractiveFlag.none,
          ),
        ),
        children: [
          if (tilesEnabled)
            TileLayer(
              urlTemplate: tileUrl,
              // A real app user-agent: some CDN edges reject the default "flutter_map (unknown)".
              tileProvider: NetworkTileProvider(
                headers: {'User-Agent': 'RidoApp/0.1 (Android; com.rido)'},
                // No disk cache, so an error image is never shown again from cache.
                cachingProvider: const DisabledMapCachingProvider(),
              ),
              subdomains: const ['a', 'b', 'c', 'd'],
              retinaMode: RetinaMode.isHighDensity(context),
              maxNativeZoom: 19,
              evictErrorTileStrategy: EvictErrorTileStrategy.dispose,
              errorTileCallback: (tile, error, stack) {},
            ),
          if (zones.isNotEmpty)
            CircleLayer(
              circles: [
                for (final z in zones)
                  CircleMarker(
                    point: z.centre,
                    radius: z.radiusM,
                    useRadiusInMeter: true,
                    color: RidoColors.coral500.withValues(alpha: 0.16),
                    borderColor: RidoColors.coral500.withValues(alpha: 0.5),
                    borderStrokeWidth: 1.5,
                  ),
              ],
            ),
          if (route.length >= 2)
            PolylineLayer(
              polylines: [
                Polyline(points: route, color: RidoColors.coral500, strokeWidth: 5, strokeCap: StrokeCap.round, strokeJoin: StrokeJoin.round),
              ],
            ),
          MarkerLayer(
            markers: [
              if (pulseAt != null)
                Marker(point: pulseAt!, width: 180, height: 180, child: PulseRing(color: pulseColor)),
              for (final z in zones)
                if (z.label != null)
                  Marker(
                    point: z.centre,
                    width: 240,
                    height: 40,
                    alignment: const Alignment(0, 3.2),
                    child: Center(child: DemandLabel(text: z.label!)),
                  ),
              if (pickup != null) Marker(point: pickup!, width: 28, height: 28, child: const PickupDot()),
              if (drop != null)
                Marker(
                  point: drop!,
                  width: 40,
                  height: 40,
                  alignment: Alignment.topCenter,
                  child: const DropPin(size: 40),
                ),
              for (final v in vehicles)
                Marker(
                  point: v.position,
                  width: v.large ? 56 : 36,
                  height: v.large ? 56 : 36,
                  child: VehicleMarker(type: v.type, heading: v.heading, large: v.large),
                ),
              ...extraMarkers,
            ],
          ),
          if (showAttribution)
            Align(
              alignment: attributionAlignment,
              child: Container(
                margin: const EdgeInsets.all(4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(4)),
                child: Text(
                  '© OpenStreetMap contributors © CARTO',
                  style: context.type.caption.copyWith(fontSize: 9, color: RidoColors.navy500),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// "High demand: Gandhipuram" chip shown under a demand zone.
class DemandLabel extends StatelessWidget {
  const DemandLabel({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: RidoRadii.pillRadius, boxShadow: RidoShadows.soft),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Symbols.local_fire_department_rounded, size: 16, color: RidoColors.coral600, fill: 1),
            const SizedBox(width: 4),
            Flexible(
              child: Text(text,
                  overflow: TextOverflow.ellipsis,
                  style: context.type.bodySmallMedium.copyWith(color: RidoColors.coral600, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
}

/// Round white floating button used over maps (back, recentre, share).
class MapCircleButton extends StatelessWidget {
  const MapCircleButton({super.key, required this.icon, required this.onPressed, required this.tooltip, this.size = 48});

  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;
  final double size;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.white,
          shape: const CircleBorder(),
          elevation: 3,
          shadowColor: RidoColors.shadow,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: SizedBox(width: size, height: size, child: Icon(icon, color: RidoColors.navy900)),
          ),
        ),
      );
}
