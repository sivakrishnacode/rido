import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rido_data/rido_data.dart';

import '../router/routes.dart';
import 'app_notice.dart';
import 'live_trip.dart';
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

/// The parcel phase for an API trip [status], or null to ignore the update. A driver who cancels after
/// accepting sends the booking back to SEARCHING (PP-07 again).
ParcelPhase? parcelPhaseForStatus(String status) => switch (status) {
  'SEARCHING' => ParcelPhase.searching,
  'NO_DRIVERS' => ParcelPhase.noDrivers,
  'DRIVER_ASSIGNED' => ParcelPhase.assigned,
  'DRIVER_ARRIVED' => ParcelPhase.atPickup,
  'PICKED_UP' => ParcelPhase.inTransit,
  'DELIVERED' => ParcelPhase.delivered,
  'CANCELLED' => ParcelPhase.planning,
  _ => null,
};

const Object _keep = Object();

/// Parcel details for a new booking with the live API: nothing seeded, the sender comes from the profile.
const ParcelDetails kEmptyParcelDetails = ParcelDetails(
  category: ParcelCategory.clothes,
  weight: WeightBand.under5,
  senderName: '',
  senderPhone: '',
  receiverName: '',
  receiverPhone: '',
  deliveryOtp: '',
);

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
    this.approach = const [],
    this.etaMin = 23,
    this.chat = const [],
    this.serverQuotes,
    this.quotesError,
    this.tripQuote,
    this.busy = false,
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

  /// Live API: driver's first fix → pickup polyline (empty until the driver's GPS arrives).
  final List<LatLng> approach;
  final int etaMin;

  /// Live API: chat with the goods driver (mock mode chats through the ride flow).
  final List<ChatMessage> chat;

  /// Live API: goods fares quoted by the server (null while loading).
  final List<FareQuote>? serverQuotes;
  final String? quotesError;

  /// Live API: the fare stored with the booked parcel.
  final FareQuote? tripQuote;
  final bool busy;

  RouteEstimate get estimate {
    final q = tripQuote ?? (serverQuotes?.isNotEmpty ?? false ? serverQuotes!.first : null);
    return q != null
        ? RouteEstimate(distanceKm: q.distanceKm, durationMin: q.durationMin)
        : FareEngine.estimate(pickup, drop);
  }

  List<FareQuote> get quotes => serverQuotes ?? FareEngine.quoteAll(Seed.goodsVehicles, estimate);

  FareQuote get quote {
    final booked = tripQuote;
    if (booked != null) return booked;
    final all = quotes;
    return all.firstWhere((q) => q.vehicle.kind == vehicle, orElse: () => all.first);
  }

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

  List<LatLng> get routeOrDefault =>
      route.isNotEmpty ? route : roadPath(pickup.location, drop.location, mode: travelModeFor(vehicle));

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
    List<LatLng>? approach,
    int? etaMin,
    List<ChatMessage>? chat,
    Object? serverQuotes = _keep,
    Object? quotesError = _keep,
    Object? tripQuote = _keep,
    bool? busy,
  }) => ParcelFlowState(
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
    approach: approach ?? this.approach,
    etaMin: etaMin ?? this.etaMin,
    chat: chat ?? this.chat,
    serverQuotes: identical(serverQuotes, _keep) ? this.serverQuotes : serverQuotes as List<FareQuote>?,
    quotesError: identical(quotesError, _keep) ? this.quotesError : quotesError as String?,
    tripQuote: identical(tripQuote, _keep) ? this.tripQuote : tripQuote as FareQuote?,
    busy: busy ?? this.busy,
  );
}

/// Runs a parcel booking.
///
/// Mock mode: PP-07 search (3 s) → PP-08 driver drives to pickup (4 s) → at pickup → "Picked up" (2 s) →
/// PP-09 in transit → PP-10 delivered.
///
/// Live API mode: books with [LiveTrips] (`kind: parcel`, details + payer), follows SEARCHING → DRIVER_ASSIGNED →
/// DRIVER_ARRIVED → PICKED_UP → DELIVERED with the driver's GPS, and shows the delivery OTP from the server.
class ParcelFlowController extends Notifier<ParcelFlowState> {
  final TripSimulator _sim = TripSimulator(tick: SimTimings.tick);
  final ValueNotifier<VehicleFix?> _liveFix = ValueNotifier<VehicleFix?>(null);
  LiveTripSession? _session;

  /// Last applied API status (drops late, older answers).
  String? _lastStatus;
  LatLng? _lastPoint;
  bool _cancelledByMe = false;

  /// The passenger chose the pickup themselves (the device location no longer replaces it).
  bool _pickupChosen = false;

  bool get _live => ref.read(isLiveApiProvider);

  ValueListenable<VehicleFix?> get vehicle => _live ? _liveFix : _sim.vehicle;

  @override
  ParcelFlowState build() {
    ref.onDispose(() {
      _sim.cancelAll();
      _stopFollowing();
    });
    if (ref.read(isLiveApiProvider)) return _freshLive();
    Future.microtask(_refreshRoute);
    return ParcelFlowState(route: roadPath(Seed.peelamedu.location, Seed.raceCourse.location));
  }

  ParcelFlowState _freshLive() => ParcelFlowState(
    pickup: ref.read(placesRepositoryProvider).currentLocation,
    details: kEmptyParcelDetails,
    driver: Seed.selvam,
    tripId: '',
  );

  Duration _t(Duration d) => ref.read(simTimingProvider)(d);

  RouteTravelMode get _mode => travelModeFor(state.vehicle);

  /// Swaps in the road-following route once the router answers (if the trip ends are unchanged).
  void _refreshRoute() {
    final a = state.pickup, b = state.drop;
    RoadRouter.fetch(a.location, b.location, mode: _mode).then((path) {
      if (path != null && state.pickup == a && state.drop == b) state = state.copyWith(route: path);
    });
  }

  void setPickup(Place p) {
    _pickupChosen = true;
    _setPickup(p);
  }

  /// Device location resolved: use it as the pickup unless the passenger already chose one.
  void useDeviceLocation(Place p) {
    if (_pickupChosen || state.phase != ParcelPhase.planning) return;
    _setPickup(p);
  }

  void _setPickup(Place p) {
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
      dropSet: true,
      route: roadPath(state.pickup.location, p.location, mode: _mode),
      serverQuotes: null,
      quotesError: null,
    );
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

  /// Live API: loads the server's goods fares for the current pickup / drop (PP-06). No-op in mock mode.
  Future<void> loadQuotes() async {
    if (!_live) return;
    final a = state.pickup, b = state.drop;
    state = state.copyWith(serverQuotes: null, quotesError: null);
    try {
      final quotes = await ref.read(parcelRepositoryProvider).quotes(a, b);
      // The pickup / drop moved meanwhile (e.g. GPS resolved): fetch fares for the new points instead of
      // leaving the screen on the loading skeleton.
      if (!_samePlace(state.pickup, a) || !_samePlace(state.drop, b)) return await loadQuotes();
      state = quotes.isEmpty
          ? state.copyWith(quotesError: "Couldn't get fares for this delivery. Try again.")
          : state.copyWith(serverQuotes: quotes);
    } catch (e) {
      if (_samePlace(state.pickup, a) && _samePlace(state.drop, b)) {
        state = state.copyWith(quotesError: apiErrorMessage(e));
      } else {
        return loadQuotes();
      }
    }
  }

  /// Books the parcel. Returns a user-facing error, or null once the request is searching.
  Future<String?> book() async {
    if (_live) return _bookLive();
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
    return null;
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

  // ------------------------------------------------------------- live trips
  Future<String?> _bookLive() async {
    if (state.busy) return null;
    state = state.copyWith(busy: true);
    try {
      final update = await ref
          .read(liveTripsProvider)
          .book(
            kind: TripKind.parcel,
            vehicle: state.vehicle,
            pickup: state.pickup,
            drop: state.drop,
            parcel: state.details,
          );
      _startFollowing(update, restoring: false);
      return null;
    } catch (e) {
      state = state.copyWith(busy: false);
      return apiErrorMessage(e);
    }
  }

  /// Picks up an unfinished parcel from the server (app restart).
  void restore(LiveTripUpdate update) => _startFollowing(update, restoring: true);

  void _startFollowing(LiveTripUpdate update, {required bool restoring}) {
    _stopFollowing();
    final trip = update.trip;
    _cancelledByMe = false;
    _lastStatus = null;
    _lastPoint = null;
    _liveFix.value = null;
    final details = (restoring ? trip.parcel : null) ?? state.details;
    state = state.copyWith(
      phase: ParcelPhase.searching,
      tripId: trip.id,
      bookedAt: trip.startedAt,
      pickup: restoring ? trip.pickup : null,
      drop: restoring ? trip.drop : null,
      dropSet: true,
      vehicle: trip.vehicle,
      details: details.copyWith(deliveryOtp: trip.otp),
      route: roadPath(trip.pickup.location, trip.drop.location, mode: travelModeFor(trip.vehicle)),
      approach: const [],
      chat: const [],
      tripQuote: trip.quote,
      busy: false,
    );
    _refreshRoute();
    _session = LiveTripSession(
      trips: ref.read(liveTripsProvider),
      realtime: ref.read(realtimeProvider),
      tripId: trip.id,
      onUpdate: _apply,
      onLocation: _onLocation,
      onMessage: (m) => state = state.copyWith(chat: mergeChat(state.chat, m)),
      onReconnect: _loadChat,
    )..start();
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
      if (state.tripId == id) state = state.copyWith(chat: chatWithHistory(state.chat, history));
    } catch (e) {
      debugPrint('Chat history: $e');
    }
  }

  void _apply(LiveTripUpdate u) {
    if (u.trip.id != state.tripId) return;
    if (isStaleStatus(u.status, _lastStatus)) return;
    _lastStatus = u.status;
    final next = parcelPhaseForStatus(u.status);
    if (next == null) return;
    final driver = u.trip.driver ?? state.driver;
    final otp = u.trip.otp;
    final details = otp.isNotEmpty && otp != state.details.deliveryOtp
        ? state.details.copyWith(deliveryOtp: otp)
        : null;

    switch (next) {
      case ParcelPhase.planning:
        _stopFollowing();
        final byMe = _cancelledByMe;
        state = state.copyWith(phase: ParcelPhase.planning, busy: false, tripQuote: null);
        ref.invalidate(tripHistoryProvider);
        if (!byMe) {
          final reason = u.json['cancelReason'];
          final why = reason is String && reason.trim().isNotEmpty ? ' ($reason)' : '';
          ref.read(appNoticeProvider.notifier).show('Your delivery was cancelled$why', goTo: Routes.parcel);
        }
      case ParcelPhase.noDrivers:
        _stopFollowing();
        state = state.copyWith(phase: ParcelPhase.noDrivers, busy: false);
      case ParcelPhase.searching:
        if (state.phase == ParcelPhase.assigned || state.phase == ParcelPhase.atPickup) {
          ref.read(appNoticeProvider.notifier).show('${state.driver.firstName} had to cancel. Finding another driver…');
        }
        _liveFix.value = null;
        _lastPoint = null;
        state = state.copyWith(phase: ParcelPhase.searching, approach: const [], details: details);
      case ParcelPhase.assigned:
        final fresh = state.phase != ParcelPhase.assigned;
        state = state.copyWith(
          phase: ParcelPhase.assigned,
          driver: driver,
          details: details,
          approach: fresh ? const [] : null,
          etaMin: fresh ? Seed.vehicle(state.vehicle).etaMin : null,
        );
      case ParcelPhase.atPickup:
        state = state.copyWith(phase: ParcelPhase.atPickup, driver: driver, details: details, etaMin: 0);
      case ParcelPhase.inTransit:
        final entering = state.phase != ParcelPhase.inTransit;
        state = state.copyWith(
          phase: ParcelPhase.inTransit,
          driver: driver,
          details: details,
          etaMin: entering ? state.estimate.durationMin : null,
        );
        if (entering && _lastPoint != null) _track(_lastPoint!);
      case ParcelPhase.delivered:
        state = state.copyWith(phase: ParcelPhase.delivered, driver: driver, etaMin: 0, deliveredAt: RidoClock.now());
        ref.invalidate(tripHistoryProvider);
    }
  }

  void _onLocation(LiveLocation l) {
    if (l.tripId != state.tripId) return;
    if (state.phase == ParcelPhase.assigned && state.approach.isEmpty) {
      final from = l.point, to = state.pickup.location, mode = _mode;
      state = state.copyWith(approach: roadPath(from, to, mode: mode));
      RoadRouter.fetch(from, to, mode: mode).then((path) {
        if (path != null && state.phase == ParcelPhase.assigned && state.approach.isNotEmpty) {
          state = state.copyWith(approach: path);
          if (_lastPoint != null) _track(_lastPoint!);
        }
      });
    }
    _track(l.point);
  }

  void _track(LatLng point) {
    final previous = _lastPoint;
    _lastPoint = point;
    final phase = state.phase;
    final leg = phase == ParcelPhase.inTransit ? state.routeOrDefault : state.approach;
    final track = leg.isEmpty ? (progress: 0.0, remainingKm: 0.0, totalKm: 0.0) : trackOnPath(leg, point);
    _liveFix.value = VehicleFix(
      position: point,
      heading: headingFor(previous, point, _liveFix.value?.heading ?? 0),
      progress: track.progress,
    );
    final eta = switch (phase) {
      ParcelPhase.assigned when leg.isNotEmpty => etaMinutes(track.remainingKm, kApproachSpeedKmh),
      ParcelPhase.inTransit => remainingTripMinutes(track, state.estimate.durationMin),
      _ => null,
    };
    if (eta != null && eta != state.etaMin) state = state.copyWith(etaMin: eta);
  }

  /// Live API: chat with the goods driver (PP-08 Chat). Mock mode chats through the ride flow.
  void sendChat(String text) => unawaited(_sendLive(text));

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
      ref.read(appNoticeProvider.notifier).show('Message not sent. ${apiErrorMessage(e)}');
    }
  }

  /// Cancel from PP-07 / PP-08. Mock: a cancelled parcel is not recorded before pickup. Live: cancels on the
  /// server (a request that ended with no drivers just closes). Returns a user-facing error, or null.
  Future<String?> cancel() async {
    if (!_live) {
      _sim.cancelAll();
      state = state.copyWith(phase: ParcelPhase.planning);
      return null;
    }
    if (!state.isActive) {
      _stopFollowing();
      state = state.copyWith(phase: ParcelPhase.planning, tripQuote: null);
      return null;
    }
    _cancelledByMe = true;
    state = state.copyWith(busy: true);
    try {
      await ref.read(liveTripsProvider).cancel(state.tripId, reason: 'Cancelled by sender');
    } catch (e) {
      _cancelledByMe = false;
      state = state.copyWith(busy: false);
      return apiErrorMessage(e);
    }
    _stopFollowing();
    state = state.copyWith(phase: ParcelPhase.planning, busy: false, tripQuote: null);
    ref.invalidate(tripHistoryProvider);
    return null;
  }

  /// PP-10 Done. Mock: adds the parcel to Activity as Delivered and resets the form. Live: sends the rating
  /// (none when not rated) and resets the form; the server already recorded the delivery.
  Future<void> finish({int? rating}) async {
    if (_live) {
      final id = state.tripId;
      _stopFollowing();
      if (rating != null) {
        try {
          await ref.read(liveTripsProvider).rate(id, rating);
        } on ApiException catch (e) {
          if (e.status != 409) ref.read(appNoticeProvider.notifier).show(e.message);
        } catch (e) {
          ref.read(appNoticeProvider.notifier).show("Couldn't send your rating. ${apiErrorMessage(e)}");
        }
      }
      ref.invalidate(tripHistoryProvider);
      _pickupChosen = false;
      final keepSender = state.details;
      state = _freshLive().copyWith(
        details: kEmptyParcelDetails.copyWith(senderName: keepSender.senderName, senderPhone: keepSender.senderPhone),
      );
      return;
    }
    _sim.cancelAll();
    final q = state.quote;
    await ref
        .read(rideRepositoryProvider)
        .addTrip(
          Trip(
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
          ),
        );
    ref.invalidate(tripHistoryProvider);
    state = ParcelFlowState(route: roadPath(Seed.peelamedu.location, Seed.raceCourse.location));
  }
}

final parcelFlowProvider = NotifierProvider<ParcelFlowController, ParcelFlowState>(ParcelFlowController.new);

/// Same place for fares: `Place ==` only compares ids, and the current location keeps its id as it moves.
bool _samePlace(Place a, Place b) => a.id == b.id && a.location == b.location;
