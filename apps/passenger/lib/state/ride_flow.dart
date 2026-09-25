import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rido_data/rido_data.dart';

import 'passenger_session.dart';

/// Where the current ride is. Screens listen and navigate when it changes.
enum RidePhase {
  /// Choosing pickup, drop and vehicle.
  planning,
  searching,
  noDrivers,
  assigned,

  /// The driver cancelled; Rido is re-searching (S-02).
  driverCancelled,
  arrived,
  inProgress,

  /// Reached the drop; waiting for payment + rating.
  completed,
}

@immutable
class RideFlowState {
  const RideFlowState({
    this.pickup = Seed.gandhipuram,
    this.drop = Seed.brookefields,
    this.vehicle = VehicleKind.bike,
    this.preferWomenDriver = false,
    this.phase = RidePhase.planning,
    this.driver = Seed.karthik,
    this.tripId = 'RD-DEMO',
    this.bookedAt,
    this.route = const [],
    this.approach = const [],
    this.etaMin = 3,
    this.chat = const [],
    this.driverCancelledOnce = false,
  });

  final Place pickup;
  final Place drop;
  final VehicleKind vehicle;
  final bool preferWomenDriver;
  final RidePhase phase;
  final DriverProfile driver;
  final String tripId;
  final DateTime? bookedAt;

  /// Pickup → drop polyline.
  final List<LatLng> route;

  /// Driver start → pickup polyline.
  final List<LatLng> approach;

  /// Minutes to pickup (assigned) or to drop (in progress).
  final int etaMin;
  final List<ChatMessage> chat;
  final bool driverCancelledOnce;

  RouteEstimate get estimate => FareEngine.estimate(pickup, drop);

  /// Quotes for Bike, Auto, Cab on the current route (pure fare engine, no loading).
  List<FareQuote> get quotes => FareEngine.quoteAll(Seed.rideVehicles, estimate);

  FareQuote get quote => quotes.firstWhere((q) => q.vehicle.kind == vehicle);

  /// True while a booked ride has not been paid and rated yet.
  bool get isActive => phase != RidePhase.planning && phase != RidePhase.noDrivers;

  /// Pickup → drop route, or a generated one if none has been built yet.
  List<LatLng> get routeOrDefault => route.isNotEmpty ? route : roadPath(pickup.location, drop.location);

  RideFlowState copyWith({
    Place? pickup,
    Place? drop,
    VehicleKind? vehicle,
    bool? preferWomenDriver,
    RidePhase? phase,
    DriverProfile? driver,
    String? tripId,
    DateTime? bookedAt,
    List<LatLng>? route,
    List<LatLng>? approach,
    int? etaMin,
    List<ChatMessage>? chat,
    bool? driverCancelledOnce,
  }) =>
      RideFlowState(
        pickup: pickup ?? this.pickup,
        drop: drop ?? this.drop,
        vehicle: vehicle ?? this.vehicle,
        preferWomenDriver: preferWomenDriver ?? this.preferWomenDriver,
        phase: phase ?? this.phase,
        driver: driver ?? this.driver,
        tripId: tripId ?? this.tripId,
        bookedAt: bookedAt ?? this.bookedAt,
        route: route ?? this.route,
        approach: approach ?? this.approach,
        etaMin: etaMin ?? this.etaMin,
        chat: chat ?? this.chat,
        driverCancelledOnce: driverCancelledOnce ?? this.driverCancelledOnce,
      );
}

/// Runs a passenger ride end to end with timers, like a backend pushing updates:
/// book → searching (3 s) → assigned (driver drives to pickup, 5 s) → arrived →
/// driver enters OTP (4 s) → in progress (vehicle moves along the route) → completed.
///
/// Timers live here (not in screens) so the trip keeps going when the passenger leaves
/// P-16 and comes back from the Home "Trip in progress" banner.
class RideFlowController extends Notifier<RideFlowState> {
  final TripSimulator _sim = TripSimulator(tick: SimTimings.tick);

  /// Live vehicle marker position for map screens.
  ValueListenable<VehicleFix?> get vehicle => _sim.vehicle;

  @override
  RideFlowState build() {
    ref.onDispose(_sim.cancelAll);
    Future.microtask(_refreshRoute);
    final chat = ref.read(rideRepositoryProvider).chatSeed();
    return RideFlowState(chat: chat, route: roadPath(Seed.gandhipuram.location, Seed.brookefields.location));
  }

  Duration _t(Duration d) => ref.read(simTimingProvider)(d);

  /// Swaps in the road-following route once OSRM answers (if the trip ends are unchanged).
  void _refreshRoute() {
    final a = state.pickup, b = state.drop;
    RoadRouter.fetch(a.location, b.location).then((path) {
      if (path != null && state.pickup == a && state.drop == b) state = state.copyWith(route: path);
    });
  }
  DemoSettings get _demo => ref.read(demoSettingsProvider);

  // ---------------------------------------------------------------- planning
  void setPickup(Place p) {
    state = state.copyWith(pickup: p, route: roadPath(p.location, state.drop.location));
    _refreshRoute();
  }

  void setDrop(Place p) {
    state = state.copyWith(drop: p, route: roadPath(state.pickup.location, p.location));
    _refreshRoute();
  }

  void selectVehicle(VehicleKind v) => state = state.copyWith(vehicle: v);

  void setPreferWomenDriver(bool v) => state = state.copyWith(preferWomenDriver: v);

  // ----------------------------------------------------------------- booking
  /// Books the selected vehicle and starts the simulated trip.
  void book() {
    _sim.cancelAll();
    final now = RidoClock.now();
    state = state.copyWith(
      phase: RidePhase.searching,
      tripId: 'RD-${now.millisecondsSinceEpoch % 100000000}',
      bookedAt: now,
      route: roadPath(state.pickup.location, state.drop.location),
      driverCancelledOnce: false,
      chat: ref.read(rideRepositoryProvider).chatSeed(),
    );
    _search(_t(SimTimings.findDriver));
  }

  void _search(Duration delay) {
    _sim.after(delay, () async {
      final driver = await ref.read(rideRepositoryProvider).findDriver(state.vehicle);
      if (state.phase != RidePhase.searching && state.phase != RidePhase.driverCancelled) return;
      if (driver == null) {
        state = state.copyWith(phase: RidePhase.noDrivers);
        return;
      }
      _assign(driver);
    });
  }

  void _assign(DriverProfile driver) {
    final start = offsetPoint(state.pickup.location, 900, 35);
    final approach = roadPath(start, state.pickup.location, bend: -0.2);
    state = state.copyWith(phase: RidePhase.assigned, driver: driver, approach: approach, etaMin: 3);
    final arriveIn = _t(SimTimings.driverArrives);

    if (_demo.driverCancels && !state.driverCancelledOnce) {
      // Driver starts moving, then cancels part-way; Rido re-searches automatically.
      _sim.animateAlong(approach, arriveIn);
      _sim.after(Duration(milliseconds: arriveIn.inMilliseconds * 2 ~/ 5), () {
        _sim.cancelAll();
        state = state.copyWith(phase: RidePhase.driverCancelled, driverCancelledOnce: true);
        _search(_t(SimTimings.reSearchAfterCancel));
      });
      return;
    }

    _sim.animateAlong(
      approach,
      arriveIn,
      onProgress: (p) => _setEta((3 * (1 - p)).ceil().clamp(1, 3)),
      onDone: _arrive,
    );
  }

  void _arrive() {
    state = state.copyWith(phase: RidePhase.arrived, etaMin: 0);
    _sim.after(_t(SimTimings.driverEntersOtp), _startRide);
  }

  void _startRide() {
    final total = state.estimate.durationMin;
    state = state.copyWith(phase: RidePhase.inProgress, etaMin: total);
    _sim.animateAlong(
      state.route,
      _t(SimTimings.rideDuration),
      onProgress: (p) => _setEta((total * (1 - p)).ceil()),
      onDone: () => state = state.copyWith(phase: RidePhase.completed, etaMin: 0),
    );
  }

  void _setEta(int eta) {
    if (eta != state.etaMin) state = state.copyWith(etaMin: eta);
  }

  /// S-01 "Try Auto · ₹72": switch vehicle and search again.
  void retryWith(VehicleKind v) {
    state = state.copyWith(vehicle: v);
    book();
  }

  // ------------------------------------------------------------------- chat
  void sendChat(String text) {
    final now = RidoClock.now();
    final mine = ChatMessage(id: 'c${now.microsecondsSinceEpoch}', text: text, fromMe: true, sentAt: now);
    state = state.copyWith(chat: [...state.chat, mine]);
    final replies = Seed.driverReplies;
    final sentByMe = state.chat.where((m) => m.fromMe).length;
    _sim.after(_t(SimTimings.chatReply), () {
      final reply = ChatMessage(
        id: 'r${DateTime.now().microsecondsSinceEpoch}',
        text: replies[(sentByMe - 1) % replies.length],
        fromMe: false,
        sentAt: RidoClock.now(),
      );
      state = state.copyWith(chat: [...state.chat, reply]);
    });
  }

  // ----------------------------------------------------------------- ending
  /// Passenger cancelled (S-03). Adds a Cancelled trip to Activity.
  Future<void> cancelRide({String? reason}) async {
    _sim.cancelAll();
    if (state.phase != RidePhase.planning) {
      await ref.read(rideRepositoryProvider).addTrip(_trip(TripStatus.cancelled));
      ref.invalidate(tripHistoryProvider);
    }
    state = state.copyWith(phase: RidePhase.planning);
  }

  /// Cancel while still searching / no drivers: nothing is recorded.
  void cancelSearch() {
    _sim.cancelAll();
    state = state.copyWith(phase: RidePhase.planning);
  }

  /// P-20 Submit / Skip. Adds the trip to the top of Activity as Completed.
  Future<void> finishRide({int? rating}) async {
    _sim.cancelAll();
    await ref.read(rideRepositoryProvider).addTrip(_trip(TripStatus.completed, rating: rating));
    ref.invalidate(tripHistoryProvider);
    state = state.copyWith(phase: RidePhase.planning);
  }

  Trip _trip(TripStatus status, {int? rating}) {
    final q = state.quote;
    return Trip(
      id: state.tripId,
      kind: TripKind.ride,
      vehicle: state.vehicle,
      pickup: state.pickup,
      drop: state.drop,
      fare: q.total,
      quote: q,
      status: status,
      startedAt: state.bookedAt ?? RidoClock.now(),
      driver: state.driver,
      distanceKm: q.distanceKm,
      durationMin: q.durationMin,
      rating: rating,
    );
  }
}

final rideFlowProvider = NotifierProvider<RideFlowController, RideFlowState>(RideFlowController.new);
