part of 'rido_map.dart';

// Google Maps SDK engine for [RidoMap]. Only built when [RidoMap.usesGoogle] is true, so tests
// (tilesEnabled = false) and key-less builds never create a platform view.

gm.LatLng _g(LatLng p) => gm.LatLng(p.latitude, p.longitude);
LatLng _l(gm.LatLng p) => LatLng(p.latitude, p.longitude);

/// Web-Mercator maths in Google's world of 256 logical px at zoom 0 (same as flutter_map's
/// EPSG:3857), used to fit points before the map exists and to place widget overlays.
abstract final class _Mercator {
  static Offset world(LatLng p, double zoom) {
    final scale = 256 * math.pow(2, zoom).toDouble();
    final s = math.sin(p.latitude * math.pi / 180).clamp(-0.9999, 0.9999);
    return Offset((p.longitude + 180) / 360 * scale, (0.5 - math.log((1 + s) / (1 - s)) / (4 * math.pi)) * scale);
  }

  static LatLng unproject(Offset w, double zoom) {
    final scale = 256 * math.pow(2, zoom).toDouble();
    final n = math.pi - 2 * math.pi * w.dy / scale;
    final lat = 180 / math.pi * math.atan(0.5 * (math.exp(n) - math.exp(-n)));
    return LatLng(lat, w.dx / scale * 360 - 180);
  }

  /// Camera that fits [points] inside [size] minus [padding] (like flutter_map's CameraFit).
  static (LatLng, double) fit(
    List<LatLng> points,
    Size size,
    EdgeInsets padding, {
    double minZoom = 10,
    double maxZoom = 16,
  }) {
    var minX = double.infinity, minY = double.infinity, maxX = -double.infinity, maxY = -double.infinity;
    for (final p in points) {
      final w = world(p, 0);
      minX = math.min(minX, w.dx);
      maxX = math.max(maxX, w.dx);
      minY = math.min(minY, w.dy);
      maxY = math.max(maxY, w.dy);
    }
    final availW = math.max(1.0, size.width - padding.horizontal);
    final availH = math.max(1.0, size.height - padding.vertical);
    final dx = maxX - minX, dy = maxY - minY;
    final zx = dx > 0 ? math.log(availW / dx) / math.ln2 : maxZoom;
    final zy = dy > 0 ? math.log(availH / dy) / math.ln2 : maxZoom;
    final zoom = math.min(zx, zy).clamp(minZoom, maxZoom).toDouble();
    final scale = math.pow(2, zoom).toDouble();
    final centre = Offset((minX + maxX) / 2 * scale, (minY + maxY) / 2 * scale);
    // Shift so the fitted box sits in the padded area, not the raw centre.
    final target = centre - Offset((padding.left - padding.right) / 2, (padding.top - padding.bottom) / 2);
    return (unproject(target, zoom), zoom);
  }
}

/// Marker bitmaps rendered once from the Rido widgets and cached per kind / pixel ratio.
abstract final class _MarkerBitmaps {
  static const pad = 6.0;
  static final Map<String, Future<gm.BitmapDescriptor>> _cache = {};

  static Future<gm.BitmapDescriptor> get(String key, Widget widget, Size size, double dpr, ui.FlutterView view) {
    final cacheKey = '$key@$dpr';
    return _cache[cacheKey] ??=
        renderWidgetToPng(
          Padding(padding: const EdgeInsets.all(pad), child: widget),
          size: Size(size.width + 2 * pad, size.height + 2 * pad),
          pixelRatio: dpr,
          view: view,
        ).then<gm.BitmapDescriptor>((Uint8List png) => gm.BytesMapBitmap(png, imagePixelRatio: dpr)).catchError((
          Object e,
        ) {
          _cache.remove(cacheKey);
          throw e;
        });
  }

  /// Anchor for a marker whose point sits at [inner] (0..1 of the unpadded widget).
  static Offset anchor(Size size, Offset inner) => Offset(
    (pad + inner.dx * size.width) / (size.width + 2 * pad),
    (pad + inner.dy * size.height) / (size.height + 2 * pad),
  );
}

class _GoogleRidoMap extends StatefulWidget {
  const _GoogleRidoMap({required this.map});
  final RidoMap map;

  @override
  State<_GoogleRidoMap> createState() => _GoogleRidoMapState();
}

class _GoogleRidoMapState extends State<_GoogleRidoMap> {
  static const _pickupSize = Size(28, 28);
  static const _dropSize = Size(40, 40);
  static const _eager = <Factory<OneSequenceGestureRecognizer>>{
    Factory<OneSequenceGestureRecognizer>(EagerGestureRecognizer.new),
  };

  gm.GoogleMapController? _controller;
  gm.CameraPosition? _initial;
  late gm.CameraPosition _camera;
  Size _size = Size.zero;
  final Map<String, gm.BitmapDescriptor> _icons = {};
  final Set<String> _requested = {};
  bool _programmaticMove = false;
  (LatLng, double)? _pendingMove;

  RidoMap get m => widget.map;

  @override
  void initState() {
    super.initState();
    m.controller?._google = this;
  }

  @override
  void didUpdateWidget(covariant _GoogleRidoMap old) {
    super.didUpdateWidget(old);
    if (old.map.controller != m.controller) {
      if (old.map.controller?._google == this) old.map.controller!._google = null;
      m.controller?._google = this;
    }
  }

  @override
  void dispose() {
    if (m.controller?._google == this) m.controller!._google = null;
    super.dispose();
  }

  void _moveTo(LatLng center, double zoom) {
    final c = _controller;
    if (c == null) {
      _pendingMove = (center, zoom);
      return;
    }
    _programmaticMove = true;
    unawaited(c.moveCamera(gm.CameraUpdate.newLatLngZoom(_g(center), zoom)).catchError((Object _) {}));
  }

  void _onCreated(gm.GoogleMapController c) {
    _controller = c;
    final pending = _pendingMove;
    _pendingMove = null;
    if (pending != null) _moveTo(pending.$1, pending.$2);
  }

  bool get _hasOverlays => m.pulseAt != null || m.extraMarkers.isNotEmpty || m.zones.any((z) => z.label != null);

  void _onCameraMove(gm.CameraPosition pos) {
    _camera = pos;
    if (_hasOverlays) setState(() {});
    m.onPositionChanged?.call(RidoCamera(center: _l(pos.target), zoom: pos.zoom), !_programmaticMove);
  }

  gm.CameraPosition _initialCamera(Size size) {
    final fit = m.fitPoints;
    if (fit != null && fit.length >= 2) {
      final (centre, zoom) = _Mercator.fit(fit, size, m.fitPadding);
      return gm.CameraPosition(target: _g(centre), zoom: zoom);
    }
    return gm.CameraPosition(target: _g(m.center ?? m.pickup ?? const LatLng(11.0168, 76.9658)), zoom: m.zoom);
  }

  // ---- markers ----

  static String _vehicleKey(MapVehicle v) => 'vehicle-${v.type.name}-${v.large}';
  static Size _vehicleSize(MapVehicle v) => Size.square(v.large ? 56 : 36);

  void _ensureIcons(double dpr) {
    final view = View.of(context);
    void need(String key, Widget w, Size size) {
      if (_requested.contains(key)) return;
      _requested.add(key);
      _MarkerBitmaps.get(key, w, size, dpr, view).then(
        (icon) {
          if (mounted) setState(() => _icons[key] = icon);
        },
        onError: (Object e) {
          _requested.remove(key);
          debugPrint('RidoMap: marker bitmap failed: $e');
        },
      );
    }

    if (m.pickup != null) need('pickup', const PickupDot(), _pickupSize);
    if (m.drop != null) need('drop', const DropPin(size: 40), _dropSize);
    for (final v in m.vehicles) {
      need(_vehicleKey(v), VehicleMarker(type: v.type, large: v.large), _vehicleSize(v));
    }
  }

  Set<gm.Marker> _markers() {
    final out = <gm.Marker>{};
    final pickupIcon = _icons['pickup'];
    if (m.pickup != null && pickupIcon != null) {
      out.add(
        gm.Marker(
          markerId: const gm.MarkerId('pickup'),
          position: _g(m.pickup!),
          icon: pickupIcon,
          anchor: const Offset(0.5, 0.5),
          consumeTapEvents: true,
          zIndexInt: 2,
        ),
      );
    }
    final dropIcon = _icons['drop'];
    if (m.drop != null && dropIcon != null) {
      out.add(
        gm.Marker(
          markerId: const gm.MarkerId('drop'),
          position: _g(m.drop!),
          icon: dropIcon,
          // flutter_map path draws the 40 px pin above the point (Alignment.topCenter).
          anchor: _MarkerBitmaps.anchor(_dropSize, const Offset(0.5, 1)),
          consumeTapEvents: true,
          zIndexInt: 3,
        ),
      );
    }
    for (var i = 0; i < m.vehicles.length; i++) {
      final v = m.vehicles[i];
      final icon = _icons[_vehicleKey(v)];
      if (icon == null) continue;
      out.add(
        gm.Marker(
          markerId: gm.MarkerId('vehicle-$i'),
          position: _g(v.position),
          icon: icon,
          rotation: v.heading,
          flat: true,
          anchor: const Offset(0.5, 0.5),
          consumeTapEvents: true,
          zIndexInt: v.large ? 4 : 1,
        ),
      );
    }
    return out;
  }

  // ---- widget overlays (pulse ring, zone labels, extra markers) ----

  Offset _screen(LatLng p) {
    final z = _camera.zoom;
    return _Mercator.world(p, z) - _Mercator.world(_l(_camera.target), z) + _size.center(Offset.zero);
  }

  Widget? _overlay(LatLng point, double width, double height, Alignment alignment, Widget child) {
    final s = _screen(point);
    final left = 0.5 * width * (alignment.x + 1);
    final top = 0.5 * height * (alignment.y + 1);
    final x = s.dx - (width - left);
    final y = s.dy - (height - top);
    if (x > _size.width || y > _size.height || x + width < 0 || y + height < 0) return null;
    return Positioned(
      left: x,
      top: y,
      width: width,
      height: height,
      child: IgnorePointer(child: child),
    );
  }

  List<Widget> _overlays() => [
    if (m.pulseAt != null) _overlay(m.pulseAt!, 180, 180, Alignment.center, PulseRing(color: m.pulseColor)),
    for (final z in m.zones)
      if (z.label != null)
        _overlay(z.centre, 240, 40, const Alignment(0, 3.2), Center(child: DemandLabel(text: z.label!))),
    for (final mk in m.extraMarkers)
      _overlay(mk.point, mk.width, mk.height, mk.alignment ?? Alignment.center, mk.child),
  ].nonNulls.toList();

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    _ensureIcons(dpr);
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        _size = size.isFinite ? size : const Size(360, 640);
        final initial = _initial ??= _camera = _initialCamera(_size);
        return ClipRect(
          child: ColoredBox(
            color: RidoColors.inputBg,
            child: Stack(
              children: [
                Positioned.fill(
                  child: gm.GoogleMap(
                    initialCameraPosition: initial,
                    padding: m.mapPadding,
                    style: ridoGoogleMapStyle,
                    onMapCreated: _onCreated,
                    onCameraMove: _onCameraMove,
                    onCameraIdle: () => _programmaticMove = false,
                    markers: _markers(),
                    polylines: {
                      if (m.route.length >= 2)
                        gm.Polyline(
                          polylineId: const gm.PolylineId('route'),
                          points: [for (final p in m.route) _g(p)],
                          color: RidoColors.coral500,
                          width: 5,
                          startCap: gm.Cap.roundCap,
                          endCap: gm.Cap.roundCap,
                          jointType: gm.JointType.round,
                        ),
                    },
                    circles: {
                      for (var i = 0; i < m.zones.length; i++)
                        gm.Circle(
                          circleId: gm.CircleId('zone-$i'),
                          center: _g(m.zones[i].centre),
                          radius: m.zones[i].radiusM,
                          fillColor: RidoColors.coral500.withValues(alpha: 0.16),
                          strokeColor: RidoColors.coral500.withValues(alpha: 0.5),
                          strokeWidth: 2,
                        ),
                    },
                    minMaxZoomPreference: const gm.MinMaxZoomPreference(10, 18),
                    compassEnabled: false,
                    mapToolbarEnabled: false,
                    zoomControlsEnabled: false,
                    myLocationButtonEnabled: false,
                    rotateGesturesEnabled: false,
                    tiltGesturesEnabled: false,
                    scrollGesturesEnabled: m.interactive,
                    zoomGesturesEnabled: m.interactive,
                    buildingsEnabled: false,
                    indoorViewEnabled: false,
                    trafficEnabled: false,
                    gestureRecognizers: m.interactive ? _eager : const {},
                  ),
                ),
                ..._overlays(),
              ],
            ),
          ),
        );
      },
    );
  }
}
