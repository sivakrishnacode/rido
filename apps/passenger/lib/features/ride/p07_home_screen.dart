import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

import '../../common/async_view.dart';
import '../../common/trip_routes.dart';
import '../../common/device_location.dart';
import '../../common/map_insets.dart';
import '../../router/routes.dart';
import '../../state/parcel_flow.dart';
import '../../state/passenger_session.dart';
import '../../state/ride_flow.dart';
import '../states/s05_location_denied_screen.dart';
import '../states/s07_loading_skeletons.dart';
import '../states/s08_service_unavailable_screen.dart';
import 'widgets/dashed_border.dart';

/// P-07 Home (Ride tab): full map around the pickup with nearby vehicles, greeting card,
/// SOS, and a half-height sheet with search, saved places, recent destinations and a promo.
/// P-07b: a "Trip in progress" banner while a ride or parcel is active.
class P07HomeScreen extends ConsumerStatefulWidget {
  const P07HomeScreen({super.key, this.showTripBanner = false, this.showcase = false});

  /// Forces the P-07b banner (Design gallery).
  final bool showTripBanner;

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  @override
  ConsumerState<P07HomeScreen> createState() => _P07HomeScreenState();
}

class _P07HomeScreenState extends ConsumerState<P07HomeScreen> {
  /// Live sheet height (fraction of the screen) so the locate button rides on top of it.
  final ValueNotifier<double?> _sheetExtent = ValueNotifier(null);

  /// Sheet size the map's padding follows, updated once a drag settles (the Google logo sits right above the
  /// sheet; re-padding the platform map on every drag frame would stutter).
  final ValueNotifier<double?> _paddedExtent = ValueNotifier(null);
  Timer? _padTimer;

  final _map = RidoMapController();

  /// Re-reads the location when the passenger comes back (e.g. from the system settings after S-05).
  AppLifecycleListener? _lifecycle;

  /// Live API: the last located point was outside the service area (banner).
  bool _outsideArea = false;

  static final LatLng _pickup = Seed.gandhipuram.location;

  /// Camera centre sits south of the pickup so the pickup shows above the sheet. On the Google engine the
  /// map is padded by the sheet instead (keeps the Google logo visible), so it centres on the pickup itself.
  static LatLng _cameraFor(LatLng pickup) => RidoMap.usesGoogle ? pickup : offsetPoint(pickup, 950, 180);
  static final LatLng _camera = _cameraFor(_pickup);
  static const double _zoom = 15;

  /// Seeded nearby vehicles (bike, auto, car) at various headings, placed around [p]
  /// (the current pickup, which follows the phone's real location).
  static List<MapVehicle> _nearbyAround(LatLng p) => [
    MapVehicle(position: offsetPoint(p, 520, 20), type: MapVehicleType.car, heading: 15),
    MapVehicle(position: offsetPoint(p, 420, 320), type: MapVehicleType.car, heading: 30),
    MapVehicle(position: offsetPoint(p, 420, 72), type: MapVehicleType.auto, heading: 110),
    MapVehicle(position: offsetPoint(p, 330, 235), type: MapVehicleType.bike, heading: 70),
    MapVehicle(position: offsetPoint(p, 360, 140), type: MapVehicleType.bike, heading: 120),
  ];

  @override
  void dispose() {
    _lifecycle?.dispose();
    _sheetExtent.dispose();
    _paddedExtent.dispose();
    _padTimer?.cancel();
    _map.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Live: the pickup is always the phone's location, and the permission is asked on every visit until given
    // (on opening and when the passenger comes back to the app; not right after the dialog closes, which would
    // loop). The seeded demo only uses a permission already given.
    if (!widget.showcase) {
      final live = ref.read(isLiveApiProvider);
      WidgetsBinding.instance.addPostFrameCallback((_) => _locate(ask: live));
      _lifecycle = AppLifecycleListener(onRestart: () => _locate(ask: live));
    }
  }

  Future<void> _locate({required bool ask}) async {
    if (!mounted || ref.read(rideFlowProvider).isActive) return;
    final r = await ref.read(deviceLocationProvider.notifier).locate(askPermission: ask);
    _moveToPickup(r);
  }

  /// The location banner's button: ask again / open the right settings page, then locate.
  Future<void> _fixLocation() async {
    final r = await ref.read(deviceLocationProvider.notifier).fixAccess();
    _moveToPickup(r);
  }

  void _moveTo(LatLng centre) {
    _map.move(centre, _zoom);
  }

  void _moveToPickup(LocateResult r) {
    if (!mounted) return;
    final live = ref.read(isLiveApiProvider);
    if (r == LocateResult.inArea || (live && r == LocateResult.outsideArea)) {
      _moveTo(_cameraFor(ref.read(rideFlowProvider).pickup.location));
    }
    if (live && (r == LocateResult.inArea || r == LocateResult.outsideArea)) {
      setState(() => _outsideArea = r == LocateResult.outsideArea);
    }
  }

  /// Locate me: asks for permission if needed, then centres on the phone's location.
  Future<void> _recentre() async {
    final r = await ref.read(deviceLocationProvider.notifier).locate();
    if (!mounted) return;
    switch (r) {
      case LocateResult.inArea:
        _moveToPickup(r);
      case LocateResult.outsideArea:
        if (!ref.read(isLiveApiProvider)) _moveTo(_camera);
        showRidoSnack(
          context,
          ref.read(isLiveApiProvider)
              ? "Rido isn't in your area yet. Choose a pickup in Coimbatore."
              : "You're outside Coimbatore. The demo keeps Gandhipuram as pickup.",
        );
      case LocateResult.denied:
        // Live: the banner explains and its button fixes it; the demo keeps S-05.
        if (!ref.read(isLiveApiProvider)) context.push(Routes.locationDenied);
      case LocateResult.unavailable:
        _moveTo(_camera);
    }
  }

  String _greeting() {
    if (widget.showcase) return 'Good afternoon,';
    final h = RidoClock.now().hour;
    if (h < 12) return 'Good morning,';
    if (h < 17) return 'Good afternoon,';
    return 'Good evening,';
  }

  void _chooseDrop(Place place) {
    ref.read(rideFlowProvider.notifier).setDrop(place);
    context.push(Routes.chooseVehicle);
  }

  @override
  Widget build(BuildContext context) {
    final demo = ref.watch(demoSettingsProvider);
    final ride = ref.watch(rideFlowProvider);
    final parcel = ref.watch(parcelFlowProvider);
    final profile = ref.watch(currentProfileProvider);

    if (!widget.showcase && demo.outsideServiceArea) {
      return const Scaffold(backgroundColor: RidoColors.surface, body: S08ServiceUnavailableView());
    }
    if (!widget.showcase && demo.locationDenied) {
      return const Scaffold(
        backgroundColor: RidoColors.surface,
        body: SafeArea(child: S05LocationDeniedView()),
      );
    }

    final tripActive = widget.showTripBanner || ride.isActive || parcel.isActive;
    final sheetSize = tripActive ? 0.42 : 0.58;
    // Decorative nearby vehicles in the seeded demo only; the live app has no feed of idle drivers.
    final showNearby = !tripActive && (widget.showcase || !ref.watch(isLiveApiProvider));

    return Scaffold(
      backgroundColor: RidoColors.surface,
      body: LayoutBuilder(
        builder: (context, c) {
          // Follows the sheet while it is dragged (see the NotificationListener below).
          return Stack(
            children: [
              Positioned.fill(
                child: ValueListenableBuilder<double?>(
                  valueListenable: _paddedExtent,
                  builder: (context, padded, _) => RidoMap(
                    controller: _map,
                    center: tripActive
                        ? (RidoMap.usesGoogle ? ride.pickup.location : offsetPoint(ride.pickup.location, 600, 180))
                        : _cameraFor(ride.pickup.location),
                    zoom: _zoom,
                    mapPadding: sheetMapPadding(c.maxHeight * (padded ?? sheetSize)),
                    pickup: ref.watch(rideFlowProvider.select((r) => r.pickup.location)),
                    vehicles: showNearby
                        ? _nearbyAround(ref.watch(rideFlowProvider.select((r) => r.pickup.location)))
                        : const [],
                    attributionAlignment: Alignment.topRight,
                    showAttribution: true,
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(RidoSpacing.l, RidoSpacing.m, RidoSpacing.l, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _GreetingCard(greeting: _greeting(), profile: profile),
                          ),
                          const SizedBox(width: RidoSpacing.s),
                          SosButton(size: 56, onPressed: () => context.push(Routes.sos)),
                        ],
                      ),
                      if (!widget.showcase) _LocationBanners(outsideArea: _outsideArea, onFix: _fixLocation),
                    ],
                  ),
                ),
              ),
              // Only this button rebuilds while the sheet is dragged (not the map or sheet).
              if (!tripActive)
                ValueListenableBuilder<double?>(
                  valueListenable: _sheetExtent,
                  builder: (context, extent, child) {
                    final e = extent ?? sheetSize;
                    if (e >= 0.8) return const SizedBox.shrink();
                    return Positioned(right: RidoSpacing.l, top: c.maxHeight * (1 - e) - 64, child: child!);
                  },
                  child: MapCircleButton(
                    icon: Symbols.my_location_rounded,
                    tooltip: 'Recentre map',
                    onPressed: _recentre,
                  ),
                ),
              if (tripActive)
                Positioned(
                  left: RidoSpacing.m,
                  right: RidoSpacing.m,
                  top: c.maxHeight * (1 - sheetSize) - 84,
                  child: _TripBanner(ride: ride, parcel: parcel, showcase: widget.showcase || widget.showTripBanner),
                ),
              NotificationListener<DraggableScrollableNotification>(
                onNotification: (n) {
                  _sheetExtent.value = n.extent;
                  _padTimer?.cancel();
                  _padTimer = Timer(const Duration(milliseconds: 180), () {
                    if (mounted) _paddedExtent.value = (n.extent * 100).round() / 100;
                  });
                  return false;
                },
                child: MapBottomSheet(
                  key: ValueKey(tripActive),
                  initialSize: sheetSize,
                  minSize: tripActive ? 0.3 : 0.34,
                  snapSizes: [sheetSize],
                  builder: (context) => tripActive ? _activeSheet(profile) : _bookingSheet(profile),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ------------------------------------------------------------------ sheets
  List<Widget> _bookingSheet(PassengerProfile profile) {
    final recent = widget.showcase
        ? const AsyncData<List<Place>>(Seed.recentDestinations)
        : ref.watch(recentDestinationsProvider);
    return [
      AsyncView<List<Place>>(
        value: recent,
        onRetry: () => ref.invalidate(recentDestinationsProvider),
        loading: const S07aHomeSheetSkeleton(),
        data: (places) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SearchField(
              hint: 'Where are you going?',
              large: true,
              readOnly: true,
              onTap: () => context.push(Routes.search),
            ),
            const SizedBox(height: RidoSpacing.l),
            _SavedPlacesRow(
              places: profile.savedPlaces,
              onPlace: (p) => _chooseDrop(p.place),
              onAdd: () => context.push(Routes.savedPlaceEditor()),
            ),
            const SizedBox(height: RidoSpacing.s),
            for (var i = 0; i < places.length; i++) ...[
              if (i > 0) const Divider(height: 1, indent: 52),
              LocationRow(
                kind: LocationRowKind.recent,
                title: places[i].name,
                subtitle: places[i].address,
                showChevron: true,
                onTap: () => _chooseDrop(places[i]),
              ),
            ],
            const SizedBox(height: RidoSpacing.l),
            const _PromoCard(),
          ],
        ),
      ),
    ];
  }

  List<Widget> _activeSheet(PassengerProfile profile) {
    void blocked() => showRidoSnack(context, 'You can book another ride after this trip ends.');
    return [
      SearchField(hint: 'Where are you going?', large: true, readOnly: true, showMic: false, onTap: blocked),
      const SizedBox(height: RidoSpacing.l),
      _SavedPlacesRow(places: profile.savedPlaces, onPlace: (_) => blocked()),
      const SizedBox(height: RidoSpacing.l),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: RidoSpacing.l, vertical: RidoSpacing.m),
        decoration: const BoxDecoration(color: RidoColors.inputBg, borderRadius: RidoRadii.cardRadius),
        child: Row(
          children: [
            const Icon(Symbols.info_rounded, size: 20, color: RidoColors.navy700),
            const SizedBox(width: RidoSpacing.m),
            Expanded(
              child: Text(
                'You can book another ride after this trip ends.',
                style: context.type.bodySmall.copyWith(color: RidoColors.navy700),
              ),
            ),
          ],
        ),
      ),
    ];
  }
}

/// Top pill: initials avatar + "Good afternoon, Priya". Tapping opens the Account tab.
class _GreetingCard extends StatelessWidget {
  const _GreetingCard({required this.greeting, required this.profile});
  final String greeting;
  final PassengerProfile profile;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Semantics(
      button: true,
      label: 'Account, ${profile.name}',
      child: Material(
        color: RidoColors.surface,
        shape: const StadiumBorder(),
        elevation: 3,
        shadowColor: RidoColors.shadow,
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: () => context.go(Routes.account),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 6, RidoSpacing.l, 6),
            child: Row(
              children: [
                RidoAvatar(initials: profile.initials, size: 44),
                const SizedBox(width: RidoSpacing.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(greeting, style: t.bodySmall.copyWith(color: RidoColors.navy500), maxLines: 1),
                      Text(profile.firstName, style: t.h2, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Home / Work shortcuts and a dashed "+ Add" tile.
class _SavedPlacesRow extends StatelessWidget {
  const _SavedPlacesRow({required this.places, required this.onPlace, this.onAdd});
  final List<SavedPlace> places;
  final ValueChanged<SavedPlace> onPlace;

  /// Null hides the "+ Add" tile (P-07b).
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final shown = places.take(2).toList();
    return SizedBox(
      height: 58,
      child: Row(
        children: [
          for (final p in shown) ...[
            Expanded(
              child: RidoCard(
                padding: const EdgeInsets.symmetric(horizontal: RidoSpacing.m),
                onTap: () => onPlace(p),
                child: SizedBox(
                  height: 56,
                  child: Row(
                    children: [
                      Icon(switch (p.kind) {
                        SavedPlaceKind.home => Symbols.home_rounded,
                        SavedPlaceKind.work => Symbols.work_rounded,
                        SavedPlaceKind.other => Symbols.star_rounded,
                      }, color: RidoColors.coral600),
                      const SizedBox(width: RidoSpacing.m),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.label, style: t.bodySemibold, maxLines: 1, overflow: TextOverflow.ellipsis),
                            Text(
                              p.place.name,
                              style: t.bodySmall.copyWith(color: RidoColors.navy500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (onAdd != null || p != shown.last) const SizedBox(width: RidoSpacing.s),
          ],
          if (onAdd != null)
            DashedBorder(
              child: Material(
                color: Colors.transparent,
                borderRadius: RidoRadii.cardRadius,
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onAdd,
                  child: SizedBox(
                    height: 58,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: RidoSpacing.m),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Symbols.add_rounded, color: RidoColors.coral600, size: 22),
                          const SizedBox(width: RidoSpacing.xs),
                          Text('Add', style: t.bodySemibold.copyWith(color: RidoColors.coral600)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// "Your driver keeps 100% of your fare" promo with a coral 0% circle.
class _PromoCard extends StatelessWidget {
  const _PromoCard();

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Container(
      padding: const EdgeInsets.fromLTRB(RidoSpacing.l, RidoSpacing.l, RidoSpacing.m, RidoSpacing.l),
      decoration: const BoxDecoration(color: RidoColors.coral50, borderRadius: RidoRadii.cardRadius),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your driver keeps 100% of your fare', style: t.bodySemibold),
                const SizedBox(height: 2),
                Text(
                  'Rido is free for drivers: 0% commission, no subscription.',
                  style: t.bodySmall.copyWith(color: RidoColors.navy700),
                ),
              ],
            ),
          ),
          const SizedBox(width: RidoSpacing.m),
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: RidoColors.coral500, shape: BoxShape.circle),
            child: Text('0%', style: RidoTextStyles.tabular(t.bodySemibold.copyWith(color: RidoColors.surface))),
          ),
        ],
      ),
    );
  }
}

/// P-07b navy "Trip in progress" banner with a Return button that reopens the trip.
class _TripBanner extends StatelessWidget {
  const _TripBanner({required this.ride, required this.parcel, required this.showcase});
  final RideFlowState ride;
  final ParcelFlowState parcel;
  final bool showcase;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final isParcel = !ride.isActive && parcel.isActive;
    final driver = ride.driver.firstName;
    final (IconData icon, String subtitle) = isParcel
        ? (parcel.vehicle.icon, _parcelText(parcel.phase))
        : !ride.isActive
        ? (Symbols.two_wheeler_rounded, 'Karthik · arriving 3:42 PM')
        : (
            ride.vehicle.icon,
            switch (ride.phase) {
              RidePhase.searching || RidePhase.driverCancelled => 'Finding your driver…',
              RidePhase.assigned => '$driver · at pickup in ${ride.etaMin} min',
              RidePhase.arrived => '$driver is at your pickup',
              RidePhase.inProgress =>
                '$driver · arriving ${formatTime(RidoClock.now().add(Duration(minutes: ride.etaMin)))}',
              RidePhase.completed => 'Pay $driver ${formatInr(ride.quote.total)}',
              _ => 'Trip in progress',
            },
          );

    void open() {
      if (isParcel) {
        final route = routeForParcelPhase(parcel.phase);
        if (route != null) context.go(route);
        return;
      }
      final route = routeForRidePhase(ride.phase);
      if (route != null) {
        context.push(route);
      } else {
        showRidoSnack(context, 'Your live trip opens here while a ride is on');
      }
    }

    return Semantics(
      button: true,
      label: 'Trip in progress, $subtitle. Return to trip',
      child: Material(
        color: RidoColors.navy900,
        borderRadius: const BorderRadius.all(Radius.circular(RidoRadii.sheet)),
        elevation: 4,
        shadowColor: RidoColors.shadow,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: open,
          child: Padding(
            padding: const EdgeInsets.all(RidoSpacing.m),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(color: RidoColors.coral500, borderRadius: RidoRadii.cardRadius),
                  child: Icon(icon, color: RidoColors.surface, fill: 1),
                ),
                const SizedBox(width: RidoSpacing.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isParcel ? 'Parcel in progress' : 'Trip in progress',
                        style: t.bodySemibold.copyWith(color: RidoColors.surface),
                        maxLines: 1,
                      ),
                      Text(
                        subtitle,
                        style: t.bodySmall.copyWith(color: RidoColors.divider),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: RidoSpacing.s),
                Container(
                  height: 40,
                  padding: const EdgeInsets.only(left: RidoSpacing.m, right: RidoSpacing.s),
                  decoration: const BoxDecoration(color: RidoColors.surface, borderRadius: RidoRadii.pillRadius),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Return', style: t.bodySemibold),
                      const Icon(Symbols.chevron_right_rounded, size: 20, color: RidoColors.navy900),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _parcelText(ParcelPhase p) => switch (p) {
    ParcelPhase.searching || ParcelPhase.noDrivers => 'Finding a goods driver…',
    ParcelPhase.assigned => 'Driver on the way to pickup',
    ParcelPhase.atPickup => 'Driver at pickup',
    ParcelPhase.inTransit => 'On the way to the drop',
    ParcelPhase.delivered => 'Delivered',
    ParcelPhase.planning => 'Parcel',
  };
}

/// Live: "Turn on location" while the app can't use it (with the right action), else "not in your area yet".
class _LocationBanners extends ConsumerWidget {
  const _LocationBanners({required this.outsideArea, required this.onFix});
  final bool outsideArea;
  final VoidCallback onFix;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(isLiveApiProvider)) return const SizedBox.shrink();
    final access = ref.watch(locationAccessProvider);
    final Widget? banner = switch (access) {
      LocationAccess.serviceOff => RidoBanner(
          type: RidoBannerType.warning,
          icon: Symbols.location_off_rounded,
          title: 'Turn on location',
          message: 'Rido needs your location to set your pickup and find drivers near you.',
          actionLabel: 'Turn on',
          onAction: onFix,
        ),
      LocationAccess.denied => RidoBanner(
          type: RidoBannerType.warning,
          icon: Symbols.location_off_rounded,
          title: 'Allow location access',
          message: 'Rido uses your location to set your pickup and show drivers near you. The app works best with it.',
          actionLabel: 'Allow',
          onAction: onFix,
        ),
      LocationAccess.deniedForever => RidoBanner(
          type: RidoBannerType.warning,
          icon: Symbols.location_off_rounded,
          title: 'Location is off for Rido',
          message: 'Open Settings → Permissions → Location and choose "Allow while using the app".',
          actionLabel: 'Open settings',
          onAction: onFix,
        ),
      LocationAccess.granted || LocationAccess.unknown => outsideArea
          ? const RidoBanner(
              type: RidoBannerType.info,
              icon: Symbols.wrong_location_rounded,
              title: "Rido isn't in your area yet",
              message: 'You can still book a trip inside Coimbatore by choosing the pickup yourself.',
            )
          : null,
    };
    if (banner == null) return const SizedBox.shrink();
    return Padding(padding: const EdgeInsets.only(top: RidoSpacing.s), child: banner);
  }
}
