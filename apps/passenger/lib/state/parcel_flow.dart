import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rido_data/rido_data.dart';

import 'passenger_session.dart';

enum ParcelPhase {
  /// PP-01 … PP-06: filling in details.
  planning,
  searching,
  noDrivers,

  /// Driver assigned, driving to the pickup (PP-08, stepper at "Driver assigned").
  assigned,

  /// Driver is at the pickup (PP-08, stepper at "At pickup").
  atPickup,

  /// Picked up, on the way to the drop (PP-09).
  inTransit,
  delivered,
}

@immutable
class ParcelFlowState {
  const ParcelFlowState({
    this.pickup = Seed.peelamedu,
    this.drop = Seed.raceCourse,
    this.dropSet = false,
    this.vehicle = VehicleKind.threeWheeler,
    this.details = const ParcelDetails(
      category: ParcelCategory.clothes,
      weight: WeightBand.from5to20,
      senderName: 'Priya Raman',
      senderPhone: '+91 98765 43210',
      receiverName: Seed.receiverName,
      receiverPhone: Seed.receiverPhone,
    ),
    this.noProhibitedItems = false,
    this.phase = ParcelPhase.planning,
    this.driver = Seed.selvam,
    this.tripId = 'PC-DEMO',
    this.bookedAt,
    this.deliveredAt,
    this.route = const [],
    this.etaMin = 23,
  });

  final Place pickup;
  final Place drop;

  /// False until the passenger fills in "Deliver to" (PP-01 shows "Tap to add").
  final bool dropSet;
  final VehicleKind vehicle;
  final ParcelDetails details;
  final bool noProhibitedItems;
  final ParcelPhase phase;
  final DriverProfile driver;
  final String tripId;
  final DateTime? bookedAt;
  final DateTime? deliveredAt;
  final List<LatLng> route;
  final int etaMin;

  RouteEstimate get estimate => FareEngine.estimate(pickup, drop);
  List<FareQuote> get quotes => FareEngine.quoteAll(Seed.goodsVehicles, estimate);
  FareQuote get quote => quotes.firstWhere((q) => q.vehicle.kind == vehicle);

  /// Whether [v] can carry the chosen weight band.
  bool fits(VehicleType v) => (v.capacityKg ?? 0) >= details.weight.maxKg;

  bool get isActive => phase != ParcelPhase.planning && phase != ParcelPhase.noDrivers;

  /// Stepper index: Driver assigned 0 · At pickup 1 · Picked up 2 · Delivered 3.
  int get stepIndex => switch (phase) {
        ParcelPhase.planning || ParcelPhase.searching || ParcelPhase.noDrivers || ParcelPhase.assigned => 0,
        ParcelPhase.atPickup => 1,
        ParcelPhase.inTransit => 2,
        ParcelPhase.delivered => 3,
      };

  List<LatLng> get routeOrDefault => route.isNotEmpty ? route : roadPath(pickup.location, drop.location);

  ParcelFlowState copyWith({
    Place? pickup,
    Place? drop,
    bool? dropSet,
    VehicleKind? vehicle,
    ParcelDetails? details,
    bool? noProhibitedItems,
    ParcelPhase? phase,
    DriverProfile? driver,
    String? tripId,
    DateTime? bookedAt,
    DateTime? deliveredAt,
    List<LatLng>? route,
    int? etaMin,
  }) =>
      ParcelFlowState(
        pickup: pickup ?? this.pickup,
        drop: drop ?? this.drop,
        dropSet: dropSet ?? this.dropSet,
        vehicle: vehicle ?? this.vehicle,
        details: details ?? this.details,
        noProhibitedItems: noProhibitedItems ?? this.noProhibitedItems,
        phase: phase ?? this.phase,
        driver: driver ?? this.driver,
        tripId: tripId ?? this.tripId,
        bookedAt: bookedAt ?? this.bookedAt,
        deliveredAt: deliveredAt ?? this.deliveredAt,
        route: route ?? this.route,
        etaMin: etaMin ?? this.etaMin,
      );
}

/// Runs a parcel booking: PP-07 search (3 s) → PP-08 driver drives to pickup (4 s) →
/// at pickup → "Picked up" (2 s) → PP-09 in transit → PP-10 delivered.
class ParcelFlowController extends Notifier<ParcelFlowState> {
  final TripSimulator _sim = TripSimulator(tick: SimTimings.tick);

  ValueListenable<VehicleFix?> get vehicle => _sim.vehicle;

  @override
  ParcelFlowState build() {
    ref.onDispose(_sim.cancelAll);
    Future.microtask(_refreshRoute);
    return ParcelFlowState(route: roadPath(Seed.peelamedu.location, Seed.raceCourse.location));
  }

  Duration _t(Duration d) => ref.read(simTimingProvider)(d);

  /// Swaps in the road-following route once OSRM answers (if the trip ends are unchanged).
  void _refreshRoute() {
    final a = state.pickup, b = state.drop;
    RoadRouter.fetch(a.location, b.location).then((path) {
      if (path != null && state.pickup == a && state.drop == b) state = state.copyWith(route: path);
    });
  }

  void setPickup(Place p) {
    state = state.copyWith(pickup: p, route: roadPath(p.location, state.drop.location));
    _refreshRoute();
  }

  void setDrop(Place p) {
    state = state.copyWith(drop: p, dropSet: true, route: roadPath(state.pickup.location, p.location));
    _refreshRoute();
  }

  void updateDetails(ParcelDetails d) {
    state = state.copyWith(details: d);
    // If the chosen vehicle no longer fits the weight, pick the smallest one that does.
    final current = Seed.vehicle(state.vehicle);
    if (!state.fits(current)) {
      final fit = Seed.goodsVehicles.firstWhere(state.fits, orElse: () => Seed.truck);
      state = state.copyWith(vehicle: fit.kind);
    }
  }

  void setNoProhibitedItems(bool v) => state = state.copyWith(noProhibitedItems: v);

  void selectVehicle(VehicleKind v) => state = state.copyWith(vehicle: v);

  void setPayer(ParcelPayer p) => updateDetails(state.details.copyWith(payer: p));

  void book() {
    _sim.cancelAll();
    final now = RidoClock.now();
    state = state.copyWith(
      phase: ParcelPhase.searching,
      tripId: 'PC-${now.millisecondsSinceEpoch % 100000000}',
      bookedAt: now,
      route: roadPath(state.pickup.location, state.drop.location),
    );
    _sim.after(_t(SimTimings.findGoodsDriver), () async {
      final driver = await ref.read(rideRepositoryProvider).findDriver(state.vehicle);
      if (state.phase != ParcelPhase.searching) return;
      if (driver == null) {
        state = state.copyWith(phase: ParcelPhase.noDrivers);
        return;
      }
      _assign(driver);
    });
  }

  void _assign(DriverProfile driver) {
    final start = offsetPoint(state.pickup.location, 1100, 210);
    state = state.copyWith(phase: ParcelPhase.assigned, driver: driver, etaMin: 4);
    _sim.animateAlong(
      roadPath(start, state.pickup.location, bend: 0.2),
      _t(SimTimings.goodsDriverReachesPickup),
      onProgress: (p) {
        final eta = (4 * (1 - p)).ceil().clamp(1, 4);
        if (eta != state.etaMin) state = state.copyWith(etaMin: eta);
      },
      onDone: () {
        state = state.copyWith(phase: ParcelPhase.atPickup, etaMin: 0);
        _sim.after(_t(SimTimings.pickupHandover), _pickedUp);
      },
    );
  }

  void _pickedUp() {
    final total = state.estimate.durationMin;
    state = state.copyWith(phase: ParcelPhase.inTransit, etaMin: total);
    _sim.animateAlong(
      state.route,
      _t(SimTimings.parcelTransit),
      onProgress: (p) {
        final eta = (total * (1 - p)).ceil();
        if (eta != state.etaMin) state = state.copyWith(etaMin: eta);
      },
      onDone: () => state = state.copyWith(phase: ParcelPhase.delivered, etaMin: 0, deliveredAt: RidoClock.now()),
    );
  }

  /// Cancel from PP-07 / PP-08. A cancelled parcel is not recorded before pickup.
  void cancel() {
    _sim.cancelAll();
    state = state.copyWith(phase: ParcelPhase.planning);
  }

  /// PP-10 Done: adds the parcel to Activity as Delivered and resets the form.
  Future<void> finish({int? rating}) async {
    _sim.cancelAll();
    final q = state.quote;
    await ref.read(rideRepositoryProvider).addTrip(Trip(
          id: state.tripId,
          kind: TripKind.parcel,
          vehicle: state.vehicle,
          pickup: state.pickup,
          drop: state.drop,
          fare: q.total,
          quote: q,
          status: TripStatus.delivered,
          startedAt: state.bookedAt ?? RidoClock.now(),
          driver: state.driver,
          distanceKm: q.distanceKm,
          durationMin: q.durationMin,
          otp: state.details.deliveryOtp,
          parcel: state.details,
          rating: rating,
        ));
    ref.invalidate(tripHistoryProvider);
    state = ParcelFlowState(route: roadPath(Seed.peelamedu.location, Seed.raceCourse.location));
  }
}

final parcelFlowProvider = NotifierProvider<ParcelFlowController, ParcelFlowState>(ParcelFlowController.new);
