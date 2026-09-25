import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

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
  final _map = RidoMapController();
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

  void _onMove(RidoCamera camera, bool hasGesture) {
    _centre = camera.center;
    _debounce?.cancel();
    if (!_locating) setState(() => _locating = true);
    _debounce = Timer(const Duration(milliseconds: 350), _geocode);
  }

  Future<void> _geocode() async {
    final id = ++_request;
    final place = await ref.read(placesRepositoryProvider).reverseGeocode(_centre);
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
      context.push(Routes.serviceUnavailable);
      return;
    }
    if (widget.pickOnly) {
      context.pop(_place);
      return;
    }
    if (widget.forPickup) {
      ref.read(rideFlowProvider.notifier).setPickup(_place);
      showRidoSnack(context, 'Pickup set to ${_place.name}');
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
      backgroundColor: RidoColors.surface,
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: RidoMap(controller: _map, center: _initial.location, zoom: _zoom, onPositionChanged: _onMove),
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
                              padding: const EdgeInsets.symmetric(horizontal: RidoSpacing.m, vertical: 6),
                              decoration: const BoxDecoration(
                                color: RidoColors.navy900,
                                borderRadius: RidoRadii.pillRadius,
                              ),
                              child: Text(
                                widget.forPickup ? 'Pickup here' : 'Drop here',
                                style: t.bodySmallMedium.copyWith(color: RidoColors.surface),
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
                    padding: const EdgeInsets.fromLTRB(RidoSpacing.l, RidoSpacing.m, RidoSpacing.l, 0),
                    child: Row(
                      children: [
                        MapCircleButton(icon: Symbols.arrow_back_rounded, tooltip: 'Back', onPressed: _change),
                        const SizedBox(width: RidoSpacing.s),
                        Expanded(
                          child: Container(
                            height: 44,
                            padding: const EdgeInsets.symmetric(horizontal: RidoSpacing.l),
                            decoration: const BoxDecoration(
                              color: RidoColors.navy900,
                              borderRadius: RidoRadii.pillRadius,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Symbols.pan_tool_rounded, size: 20, color: RidoColors.surface),
                                const SizedBox(width: RidoSpacing.s),
                                Flexible(
                                  child: Text(
                                    widget.forPickup
                                        ? 'Move the map to set your pickup'
                                        : 'Move the map to set your drop',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: t.bodySmallMedium.copyWith(color: RidoColors.surface),
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
                  right: RidoSpacing.l,
                  bottom: RidoSpacing.xl,
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
                    const SizedBox(width: RidoSpacing.m),
                    Expanded(
                      child: _locating
                          ? const SkeletonShimmer(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(height: 4),
                                  FractionallySizedBox(widthFactor: 0.7, child: SkeletonBox(height: 16)),
                                  SizedBox(height: RidoSpacing.s),
                                  FractionallySizedBox(widthFactor: 0.9, child: SkeletonBox(height: 12)),
                                  SizedBox(height: 22),
                                ],
                              ),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_place.name, style: t.h2, maxLines: 1, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 2),
                                Text(
                                  '${_place.address}, Coimbatore',
                                  style: t.bodySmall.copyWith(color: RidoColors.navy700),
                                  maxLines: 2,
                                ),
                              ],
                            ),
                    ),
                    TextButton(
                      onPressed: _change,
                      style: TextButton.styleFrom(
                        foregroundColor: RidoColors.coral600,
                        minimumSize: const Size(48, 48),
                      ),
                      child: Text('Change', style: t.bodySemibold.copyWith(color: RidoColors.coral600)),
                    ),
                  ],
                ),
                const SizedBox(height: RidoSpacing.l),
                RidoButton(
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
