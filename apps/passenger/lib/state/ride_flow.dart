import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rido_data/rido_data.dart';

import '../router/routes.dart';
import 'app_notice.dart';
import 'live_trip.dart';
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

/// The ride phase for an API trip [status], or null to ignore the update.
///
/// Back to SEARCHING after a driver was assigned means that driver cancelled and dispatch is looking
/// again (S-02); it stays on S-02 until someone new accepts.
RidePhase? ridePhaseForStatus(String status, RidePhase current) => switch (status) {
  'SEARCHING' => switch (current) {
    RidePhase.assigned || RidePhase.arrived || RidePhase.driverCancelled => RidePhase.driverCancelled,
    _ => RidePhase.searching,
  },
  'NO_DRIVERS' => RidePhase.noDrivers,
  'DRIVER_ASSIGNED' => RidePhase.assigned,
  'DRIVER_ARRIVED' => RidePhase.arrived,
  'IN_PROGRESS' => RidePhase.inProgress,
  'COMPLETED' => RidePhase.completed,
  'CANCELLED' => RidePhase.planning,
  _ => null,
};

const Object _keep = Object();

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
    this.otp = Seed.rideOtp,
    this.serverQuotes,
    this.quotesError,
    this.tripQuote,
    this.busy = false,
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

  /// The 4-digit code the passenger tells the driver to start the ride (from the server when live).
  final String otp;

  /// Live API: fares quoted by the server for the current pickup / drop (null while loading).
  final List<FareQuote>? serverQuotes;

  /// Live API: why [serverQuotes] couldn't be loaded (user-facing).
  final String? quotesError;

  /// Live API: the fare stored with the booked trip.
  final FareQuote? tripQuote;

  /// A booking / cancel request is on its way to the server.
  final bool busy;

  RouteEstimate get estimate {
    final q = tripQuote ?? (serverQuotes?.isNotEmpty ?? false ? serverQuotes!.first : null);
    return q != null
        ? RouteEstimate(distanceKm: q.distanceKm, durationMin: q.durationMin)
        : FareEngine.estimate(pickup, drop);
  }

  /// Quotes for Bike, Auto, Cab on the current route: the server's when live, else the pure fare engine.
  List<FareQuote> get quotes => serverQuotes ?? FareEngine.quoteAll(Seed.rideVehicles, estimate);

  FareQuote get quote {
    final booked = tripQuote;
    if (booked != null) return booked;
    final all = quotes;
    return all.firstWhere((q) => q.vehicle.kind == vehicle, orElse: () => all.first);
  }

  /// True while a booked ride has not been paid and rated yet.
  bool get isActive => phase != RidePhase.planning && phase != RidePhase.noDrivers;

  /// Pickup → drop route, or a generated one if none has been built yet.
  List<LatLng> get routeOrDefault =>
      route.isNotEmpty ? route : roadPath(pickup.location, drop.location, mode: travelModeFor(vehicle));

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
    String? otp,
    Object? serverQuotes = _keep,
    Object? quotesError = _keep,
    Object? tripQuote = _keep,
    bool? busy,
  }) => RideFlowState(
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
    otp: otp ?? this.otp,
    serverQuotes: identical(serverQuotes, _keep) ? this.serverQuotes : serverQuotes as List<FareQuote>?,
    quotesError: identical(quotesError, _keep) ? this.quotesError : quotesError as String?,
    tripQuote: identical(tripQuote, _keep) ? this.tripQuote : tripQuote as FareQuote?,
    busy: busy ?? this.busy,
  );
}

/// Runs a passenger ride end to end.
///
/// Mock mode (tests, design gallery): timers, like a backend pushing updates:
/// book → searching (3 s) → assigned (driver drives to pickup, 5 s) → arrived →
/// driver enters OTP (4 s) → in progress (vehicle moves along the route) → completed.
///
/// Live API mode ([isLiveApiProvider]): books with [LiveTrips], follows the trip's status, the driver's GPS
/// and chat over the socket (polling while it is down), and cancels / rates through the API.
///
/// Timers and subscriptions live here (not in screens) so the trip keeps going when the passenger leaves
/// P-16 and comes back from the Home "Trip in progress" banner.
class RideFlowController extends Notifier<RideFlowState> {
  final TripSimulator _sim = TripSimulator(tick: SimTimings.tick);

  /// Live API: the driver's last GPS fix on the current leg.
  final ValueNotifier<VehicleFix?> _liveFix = ValueNotifier<VehicleFix?>(null);
  LiveTripSession? _session;

  /// Last applied API status (drops late, older answers).
  String? _lastStatus;
  LatLng? _lastPoint;

  /// Set while the passenger's own cancel is in flight, so the resulting CANCELLED push shows no notice.
  bool _cancelledByMe = false;

  bool get _live => ref.read(isLiveApiProvider);

  /// Live vehicle marker position for map screens (simulated, or the driver's GPS when live).
  ValueListenable<VehicleFix?> get vehicle => _live ? _liveFix : _sim.vehicle;

  @override
  RideFlowState build() {
    ref.onDispose(() {
      _sim.cancelAll();
      _stopFollowing();
    });
    if (ref.read(isLiveApiProvider)) {
      final here = ref.read(placesRepositoryProvider).currentLocation;
      return RideFlowState(pickup: here, route: const []);
    }
    Future.microtask(_refreshRoute);
    final chat = ref.read(rideRepositoryProvider).chatSeed();
    return RideFlowState(chat: chat, route: roadPath(Seed.gandhipuram.location, Seed.brookefields.location));
  }

  Duration _t(Duration d) => ref.read(simTimingProvider)(d);

  RouteTravelMode get _mode => travelModeFor(state.vehicle);

  /// Swaps in the road-following route once the router answers (if the trip ends are unchanged).
  void _refreshRoute() {
    final a = state.pickup, b = state.drop;
    RoadRouter.fetch(a.location, b.location, mode: _mode).then((path) {
      if (path != null && state.pickup == a && state.drop == b) state = state.copyWith(route: path);
    });
  }

  DemoSettings get _demo => ref.read(demoSettingsProvider);

  // ---------------------------------------------------------------- planning
  void setPickup(Place p) {
    state = state.copyWith(
      pickup: p,
      route: roadPath(p.location, state.drop.location, mode: _mode),
      serverQuotes: null,
      quotesError: null,
    );
    _refreshRoute();
  }

  void setDrop(Place p) {
    state = state.copyWith(
      drop: p,
      route: roadPath(state.pickup.location, p.location, mode: _mode),
      serverQuotes: null,
      quotesError: null,
    );
    _refreshRoute();
  }

  void selectVehicle(VehicleKind v) => state = state.copyWith(vehicle: v);

  void setPreferWomenDriver(bool v) => state = state.copyWith(preferWomenDriver: v);

  /// Live API: loads the server's fares for the current pickup / drop (P-10). No-op in mock mode.
  Future<void> loadQuotes() async {
    if (!_live) return;
    final a = state.pickup, b = state.drop;
    state = state.copyWith(serverQuotes: null, quotesError: null);
    try {
      final quotes = await ref.read(rideRepositoryProvider).quotes(a, b);
      // The pickup / drop moved meanwhile (e.g. GPS resolved): fetch fares for the new points instead of
      // leaving the screen on the loading skeleton.
      if (!_samePlace(state.pickup, a) || !_samePlace(state.drop, b)) return await loadQuotes();
      if (quotes.isEmpty) {
        state = state.copyWith(quotesError: "Couldn't get fares for this trip. Try again.");
        return;
      }
      final kinds = {for (final q in quotes) q.vehicle.kind};
      state = state.copyWith(
        serverQuotes: quotes,
        vehicle: kinds.contains(state.vehicle) ? null : quotes.first.vehicle.kind,
      );
    } catch (e) {
      if (_samePlace(state.pickup, a) && _samePlace(state.drop, b)) {
        state = state.copyWith(quotesError: apiErrorMessage(e));
      } else {
        return loadQuotes();
      }
    }
  }

  // ----------------------------------------------------------------- booking
  /// Books the selected vehicle. Returns a user-facing error, or null once the request is searching.
  Future<String?> book() async {
    if (_live) return _bookLive();
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
    return null;
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

  /// S-01 "Try Auto · ₹72": switch vehicle and search again (a new booking when live).
  Future<String?> retryWith(VehicleKind v) {
    state = state.copyWith(vehicle: v);
    return book();
  }

  // ------------------------------------------------------------- live trips
  Future<String?> _bookLive() async {
    if (state.busy) return null;
    state = state.copyWith(busy: true);
    try {
      final update = await ref
          .read(liveTripsProvider)
          .book(kind: TripKind.ride, vehicle: state.vehicle, pickup: state.pickup, drop: state.drop);
      _startFollowing(update, restoring: false);
      return null;
    } catch (e) {
      state = state.copyWith(busy: false);
      return apiErrorMessage(e);
    }
  }

  /// Picks up an unfinished ride from the server (app restart). The phase tells the screen to open.
  void restore(LiveTripUpdate update) => _startFollowing(update, restoring: true);

  void _startFollowing(LiveTripUpdate update, {required bool restoring}) {
    _stopFollowing();
    final trip = update.trip;
    _cancelledByMe = false;
    _lastStatus = null;
    _lastPoint = null;
    _liveFix.value = null;
    state = state.copyWith(
      phase: RidePhase.searching,
      tripId: trip.id,
      bookedAt: trip.startedAt,
      pickup: restoring ? trip.pickup : null,
      drop: restoring ? trip.drop : null,
      vehicle: trip.vehicle,
      route: roadPath(trip.pickup.location, trip.drop.location, mode: travelModeFor(trip.vehicle)),
      approach: const [],
      driverCancelledOnce: false,
      chat: const [],
      otp: trip.otp,
      tripQuote: trip.quote,
      busy: false,
    );
    _refreshRoute();
    final session = LiveTripSession(
      trips: ref.read(liveTripsProvider),
      realtime: ref.read(realtimeProvider),
      tripId: trip.id,
      onUpdate: _apply,
      onLocation: _onLocation,
      onMessage: (m) => state = state.copyWith(chat: mergeChat(state.chat, m)),
      onReconnect: _loadChat,
    )..start();
    _session = session;
    _apply(update);
    _loadChat();
  }

  void _stopFollowing() {
    _session?.dispose();
    _session = null;
  }

  Future<void> _loadChat() async {
    final id = state.tripId;
    try {
      final history = await ref.read(liveTripsProvider).chatHistory(id);
      if (state.tripId != id) return;
      state = state.copyWith(chat: chatWithHistory(state.chat, history));
    } catch (e) {
      debugPrint('Chat history: $e');
    }
  }

  void _apply(LiveTripUpdate u) {
    if (u.trip.id != state.tripId) return;
    if (isStaleStatus(u.status, _lastStatus)) return;
    _lastStatus = u.status;
    final next = ridePhaseForStatus(u.status, state.phase);
    if (next == null) return;
    final driver = u.trip.driver ?? state.driver;
    final otp = u.trip.otp.isNotEmpty ? u.trip.otp : null;

    switch (next) {
      case RidePhase.planning:
        _stopFollowing();
        final byMe = _cancelledByMe;
        // The API cancels the trip when the driver drops it; say who, when a driver was on the way.
        final hadDriver = state.phase == RidePhase.assigned || state.phase == RidePhase.arrived;
        final who = hadDriver ? '${state.driver.firstName} cancelled the ride' : 'Your ride was cancelled';
        state = state.copyWith(phase: RidePhase.planning, busy: false, tripQuote: null);
        ref.invalidate(tripHistoryProvider);
        if (!byMe) {
          final reason = u.json['cancelReason'];
          final why = reason is String && reason.trim().isNotEmpty ? ' ($reason)' : '';
          ref.read(appNoticeProvider.notifier).show('$who$why. You can book again.', goTo: Routes.ride);
        }
      case RidePhase.noDrivers:
        _stopFollowing();
        state = state.copyWith(phase: RidePhase.noDrivers, busy: false);
      case RidePhase.searching:
        state = state.copyWith(phase: RidePhase.searching, otp: otp);
      case RidePhase.driverCancelled:
        _liveFix.value = null;
        _lastPoint = null;
        state = state.copyWith(phase: RidePhase.driverCancelled, driverCancelledOnce: true, approach: const []);
      case RidePhase.assigned:
        // Coming from any other phase starts a new approach leg (built from the driver's first fix).
        final fresh = state.phase != RidePhase.assigned;
        state = state.copyWith(
          phase: RidePhase.assigned,
          driver: driver,
          otp: otp,
          approach: fresh ? const [] : null,
          etaMin: fresh ? Seed.vehicle(state.vehicle).etaMin : null,
        );
      case RidePhase.arrived:
        state = state.copyWith(phase: RidePhase.arrived, driver: driver, otp: otp, etaMin: 0);
      case RidePhase.inProgress:
        final entering = state.phase != RidePhase.inProgress;
        state = state.copyWith(
          phase: RidePhase.inProgress,
          driver: driver,
          etaMin: entering ? state.estimate.durationMin : null,
        );
        if (entering && _lastPoint != null) _track(_lastPoint!);
      case RidePhase.completed:
        state = state.copyWith(phase: RidePhase.completed, driver: driver, etaMin: 0);
        ref.invalidate(tripHistoryProvider);
    }
  }

  void _onLocation(LiveLocation l) {
    if (l.tripId != state.tripId) return;
    final phase = state.phase;
    if (phase == RidePhase.assigned && state.approach.isEmpty) {
      // First fix of this driver: build the approach leg once (one route call per leg).
      final from = l.point, to = state.pickup.location, mode = _mode;
      state = state.copyWith(approach: roadPath(from, to, mode: mode));
      RoadRouter.fetch(from, to, mode: mode).then((path) {
        if (path != null && state.phase == RidePhase.assigned && state.approach.isNotEmpty) {
          state = state.copyWith(approach: path);
          if (_lastPoint != null) _track(_lastPoint!);
        }
      });
    }
    _track(l.point);
  }

  /// Moves the marker to [point] and updates the ETA from what is left of the current leg.
  void _track(LatLng point) {
    final previous = _lastPoint;
    _lastPoint = point;
    final phase = state.phase;
    final leg = phase == RidePhase.inProgress ? state.routeOrDefault : state.approach;
    final track = leg.isEmpty ? (progress: 0.0, remainingKm: 0.0, totalKm: 0.0) : trackOnPath(leg, point);
    _liveFix.value = VehicleFix(
      position: point,
      heading: headingFor(previous, point, _liveFix.value?.heading ?? 0),
      progress: track.progress,
    );
    switch (phase) {
      case RidePhase.assigned when leg.isNotEmpty:
        _setEta(etaMinutes(track.remainingKm, kApproachSpeedKmh));
      case RidePhase.inProgress:
        _setEta(remainingTripMinutes(track, state.estimate.durationMin));
      default:
        break;
    }
  }

  // ------------------------------------------------------------------- chat
  void sendChat(String text) {
    if (_live) {
      unawaited(_sendLive(text));
      return;
    }
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

  Future<void> _sendLive(String text) async {
    final id = state.tripId;
    final now = RidoClock.now();
    final local = ChatMessage(id: 'local-${now.microsecondsSinceEpoch}', text: text, fromMe: true, sentAt: now);
    state = state.copyWith(chat: [...state.chat, local]);
    try {
      final sent = await ref.read(liveTripsProvider).sendMessage(id, text);
      if (state.tripId != id) return;
      final hasSent = state.chat.any((m) => m.id == sent.id);
      state = state.copyWith(
        chat: [
          for (final m in state.chat)
            if (m.id == local.id) ...[if (!hasSent) sent] else m,
        ],
      );
    } catch (e) {
      if (state.tripId != id) return;
      state = state.copyWith(chat: state.chat.where((m) => m.id != local.id).toList());
      ref.read(appNoticeProvider.notifier).show("Message not sent. ${apiErrorMessage(e)}");
    }
  }

  // ----------------------------------------------------------------- ending
  /// Passenger cancelled (S-03). Mock: adds a Cancelled trip to Activity. Live: cancels on the server.
  /// Returns a user-facing error (the ride goes on), or null.
  Future<String?> cancelRide({String? reason}) async {
    if (_live) return _cancelLive(reason);
    _sim.cancelAll();
    if (state.phase != RidePhase.planning) {
      await ref.read(rideRepositoryProvider).addTrip(_trip(TripStatus.cancelled));
      ref.invalidate(tripHistoryProvider);
    }
    state = state.copyWith(phase: RidePhase.planning);
    return null;
  }

  /// Cancel while still searching / no drivers: nothing is recorded (mock). Live: a searching request is
  /// cancelled on the server; a request that already ended with no drivers just closes.
  Future<String?> cancelSearch() async {
    if (_live) {
      if (state.phase == RidePhase.noDrivers || state.phase == RidePhase.planning) {
        _stopFollowing();
        state = state.copyWith(phase: RidePhase.planning, tripQuote: null);
        return null;
      }
      return _cancelLive('Cancelled while searching');
    }
    _sim.cancelAll();
    state = state.copyWith(phase: RidePhase.planning);
    return null;
  }

  Future<String?> _cancelLive(String? reason) async {
    if (!state.isActive) {
      state = state.copyWith(phase: RidePhase.planning);
      return null;
    }
    _cancelledByMe = true;
    state = state.copyWith(busy: true);
    try {
      await ref.read(liveTripsProvider).cancel(state.tripId, reason: reason);
    } catch (e) {
      _cancelledByMe = false;
      state = state.copyWith(busy: false);
      return apiErrorMessage(e);
    }
    _stopFollowing();
    state = state.copyWith(phase: RidePhase.planning, busy: false, tripQuote: null);
    ref.invalidate(tripHistoryProvider);
    return null;
  }

  /// P-20 Submit / Skip. Mock: adds the trip to the top of Activity as Completed. Live: sends the rating
  /// (Skip sends nothing); the server already recorded the trip.
  Future<void> finishRide({int? rating}) async {
    if (_live) {
      final id = state.tripId;
      _stopFollowing();
      if (rating != null) {
        try {
          await ref.read(liveTripsProvider).rate(id, rating);
        } on ApiException catch (e) {
          // Already rated (409) is fine; anything else is worth telling.
          if (e.status != 409) ref.read(appNoticeProvider.notifier).show(e.message);
        } catch (e) {
          ref.read(appNoticeProvider.notifier).show("Couldn't send your rating. ${apiErrorMessage(e)}");
        }
      }
      ref.invalidate(tripHistoryProvider);
      ref.invalidate(recentDestinationsProvider);
      state = state.copyWith(phase: RidePhase.planning, tripQuote: null, busy: false);
      return;
    }
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

/// Same place for fares: `Place ==` only compares ids, and the current location keeps its id as it moves.
bool _samePlace(Place a, Place b) => a.id == b.id && a.location == b.location;
