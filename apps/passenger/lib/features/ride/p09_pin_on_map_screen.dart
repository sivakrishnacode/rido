import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';
import 'package:tamiltaxi_ui/tamiltaxi_ui.dart';

import '../../router/routes.dart';
import '../../state/ride_flow.dart';

/// P-09 Pin on map: move the map under a fixed coral pin; the address card follows
/// (reverse geocoded). "Confirm drop" → P-10, or S-08 when the pin is outside Coimbatore.
class P09PinOnMapScreen extends ConsumerStatefulWidget {
  const P09PinOnMapScreen({super.key, this.forPickup = false, this.pickOnly = false, this.showcase = false});

  /// Just pick a point and return it with `context.pop(place)` (used by the saved-place editor).
  final bool pickOnly;

  /// Pin the pickup instead of the drop (opened from the P-08 pickup field).
  final bool forPickup;

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  @override
  ConsumerState<P09PinOnMapScreen> createState() => _P09PinOnMapScreenState();
}

class _P09PinOnMapScreenState extends ConsumerState<P09PinOnMapScreen> {
  static const double _zoom = 16;
  final _map = TtMapController();
  late final Place _initial = widget.showcase
      ? Seed.brookefields
      : widget.forPickup
      ? ref.read(rideFlowProvider).pickup
      : ref.read(rideFlowProvider).drop;
  late Place _place = _initial;
  late LatLng _centre = _initial.location;
  bool _locating = false;
  Timer? _debounce;
  int _request = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _map.dispose();
    super.dispose();
  }

  void _onMove(TtCamera camera, bool hasGesture) {
    _centre = camera.center;
    _debounce?.cancel();
    if (!_locating) setState(() => _locating = true);
    _debounce = Timer(const Duration(milliseconds: 350), _geocode);
  }

  Future<void> _geocode() async {
    final id = ++_request;
    final centre = _centre;
    Place place;
    try {
      place = await ref.read(placesRepositoryProvider).reverseGeocode(centre);
    } catch (_) {
      // Offline / API error: keep the exact pin without an address.
      place = Place(id: 'pin-${centre.latitude},${centre.longitude}', name: 'Pinned location', address: '', location: centre);
    }
    if (!mounted || id != _request) return;
    setState(() {
      _place = place;
      _locating = false;
    });
  }

  void _recentre() {
    _map.move(_initial.location, _zoom);
  }

  void _confirm() {
    final places = ref.read(placesRepositoryProvider);
    final demo = ref.read(demoSettingsProvider);
    if (demo.outsideServiceArea || !places.isInServiceArea(_place.location)) {
      context.push(Routes.serviceUnavailable, extra: demo.outsideServiceArea ? null : _place.location);
      return;
    }
    if (widget.pickOnly) {
      context.pop(_place);
      return;
    }
    if (widget.forPickup) {
      ref.read(rideFlowProvider.notifier).setPickup(_place);
      showTtSnack(context, 'Pickup set to ${_place.name}');
      context.pop();
      return;
    }
    ref.read(rideFlowProvider.notifier).setDrop(_place);
    context.push(Routes.chooseVehicle);
  }

  void _change() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.search);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Scaffold(
      backgroundColor: TtColors.surface,
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: TtMap(controller: _map, center: _initial.location, zoom: _zoom, onPositionChanged: _onMove),
                ),
                // Fixed centre pin: its tip sits exactly on the map centre.
                IgnorePointer(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 96),
                      child: SizedBox(
                        height: 96,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: TtSpacing.m, vertical: 6),
                              decoration: const BoxDecoration(
                                color: TtColors.navy900,
                                borderRadius: TtRadii.pillRadius,
                              ),
                              child: Text(
                                widget.forPickup ? 'Pickup here' : 'Drop here',
                                style: t.bodySmallMedium.copyWith(color: TtColors.surface),
                              ),
                            ),
                            const DropPin(size: 56),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(TtSpacing.l, TtSpacing.m, TtSpacing.l, 0),
                    child: Row(
                      children: [
                        MapCircleButton(icon: Symbols.arrow_back_rounded, tooltip: 'Back', onPressed: _change),
                        const SizedBox(width: TtSpacing.s),
                        Expanded(
                          child: Container(
                            height: 44,
                            padding: const EdgeInsets.symmetric(horizontal: TtSpacing.l),
                            decoration: const BoxDecoration(
                              color: TtColors.navy900,
                              borderRadius: TtRadii.pillRadius,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Symbols.pan_tool_rounded, size: 20, color: TtColors.surface),
                                const SizedBox(width: TtSpacing.s),
                                Flexible(
                                  child: Text(
                                    widget.forPickup
                                        ? 'Move the map to set your pickup'
                                        : 'Move the map to set your drop',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: t.bodySmallMedium.copyWith(color: TtColors.surface),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  right: TtSpacing.l,
                  bottom: TtSpacing.xl,
                  child: MapCircleButton(
                    icon: Symbols.my_location_rounded,
                    tooltip: 'Recentre map',
                    onPressed: _recentre,
                  ),
                ),
              ],
            ),
          ),
          FixedBottomSheet(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(padding: EdgeInsets.only(top: 2), child: DropPin(size: 26)),
                    const SizedBox(width: TtSpacing.m),
                    Expanded(
                      child: _locating
                          ? const SkeletonShimmer(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(height: 4),
                                  FractionallySizedBox(widthFactor: 0.7, child: SkeletonBox(height: 16)),
                                  SizedBox(height: TtSpacing.s),
                                  FractionallySizedBox(widthFactor: 0.9, child: SkeletonBox(height: 12)),
                                  SizedBox(height: 22),
                                ],
                              ),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_place.name, style: t.h2, maxLines: 1, overflow: TextOverflow.ellipsis),
                                // "Near KG Hospital": where the driver will look for the rider.
                                if (_place.landmark != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Row(children: [
                                      const Icon(Symbols.location_on_rounded, size: 16, color: TtColors.coral600, fill: 1),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          _place.landmark!,
                                          key: const ValueKey('pin-landmark'),
                                          style: t.bodySemibold.copyWith(color: TtColors.coral600),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ]),
                                  ),
                                const SizedBox(height: 2),
                                Text(
                                  _place.address,
                                  style: t.bodySmall.copyWith(color: TtColors.navy700),
                                  maxLines: 2,
                                ),
                              ],
                            ),
                    ),
                    TextButton(
                      onPressed: _change,
                      style: TextButton.styleFrom(
                        foregroundColor: TtColors.coral600,
                        minimumSize: const Size(48, 48),
                      ),
                      child: Text('Change', style: t.bodySemibold.copyWith(color: TtColors.coral600)),
                    ),
                  ],
                ),
                const SizedBox(height: TtSpacing.l),
                TtButton(
                  label: widget.forPickup ? 'Confirm pickup' : 'Confirm drop',
                  onPressed: _locating ? null : _confirm,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
