import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart' show Distance, LengthUnit;
import 'package:rido_data/rido_data.dart';

import 'driver_location.dart';
import 'live_helpers.dart';

/// Where the driver's current job is.
enum JobPhase {
  none,

  /// Accepted; driving to the pickup (D-16 / D-21 step 0).
  toPickup,

  /// Ride: at pickup, entering the ride OTP (D-17). Delivery: at pickup, loading (D-21 step 1).
  atPickup,

  /// Ride: in progress (D-18). Delivery: picked up, driving to the drop (D-21 step 2).
  toDrop,

  /// Delivery only: at the drop, entering the delivery OTP (D-22a).
  atDrop,

  /// Collecting payment (D-19 / D-22b).
  collect,
}

/// A one-off message from the session for a snack bar (live API), e.g. "The passenger cancelled".
@immutable
class SessionNotice {
  const SessionNotice(this.message, {this.jobEnded = false});
  final String message;

  /// The job ended from the other side: the job screens close and Home shows.
  final bool jobEnded;
}

@immutable
class DriverSessionState {
  const DriverSessionState({
    this.online = false,
    this.goingOnline = false,
    this.selfieDoneThisSession = false,
    this.incoming,
    this.incomingExpiresAt,
    this.missedRequest = false,
    this.job,
    this.phase = JobPhase.none,
    this.route = const [],
    this.etaMin = 0,
    this.todayEarnings = Seed.todayEarnings,
    this.todayRides = Seed.todayRides,
    this.gpsLost = false,
    this.notice,
  });

  final bool online;

  /// Live API: getting a GPS fix and asking the API to go online.
  final bool goingOnline;

  /// The daily selfie check (S-13) is due the first time each app session.
  final bool selfieDoneThisSession;

  /// A request waiting for Accept / Decline (D-15 / D-20).
  final RideRequest? incoming;

  /// Live API: when the server moves the offer to the next driver.
  final DateTime? incomingExpiresAt;

  /// Show the S-11 "You missed a ride request" banner on D-14.
  final bool missedRequest;
  final RideRequest? job;
  final JobPhase phase;

  /// Polyline for the current leg (to pickup, then to drop).
  final List<LatLng> route;
  final int etaMin;
  final int todayEarnings;
  final int todayRides;

  /// Live API: no GPS fix for 30 s while online (S-16).
  final bool gpsLost;
  final SessionNotice? notice;

  bool get onJob => job != null && phase != JobPhase.none;

  DriverSessionState copyWith({
    bool? online,
    bool? goingOnline,
    bool? selfieDoneThisSession,
    RideRequest? incoming,
    DateTime? incomingExpiresAt,
    bool clearIncoming = false,
    bool? missedRequest,
    RideRequest? job,
    bool clearJob = false,
    JobPhase? phase,
    List<LatLng>? route,
    int? etaMin,
    int? todayEarnings,
    int? todayRides,
    bool? gpsLost,
    SessionNotice? notice,
  }) =>
      DriverSessionState(
        online: online ?? this.online,
        goingOnline: goingOnline ?? this.goingOnline,
        selfieDoneThisSession: selfieDoneThisSession ?? this.selfieDoneThisSession,
        incoming: clearIncoming ? null : (incoming ?? this.incoming),
        incomingExpiresAt: clearIncoming ? null : (incomingExpiresAt ?? this.incomingExpiresAt),
        missedRequest: missedRequest ?? this.missedRequest,
        job: clearJob ? null : (job ?? this.job),
        phase: phase ?? this.phase,
        route: route ?? this.route,
        etaMin: etaMin ?? this.etaMin,
        todayEarnings: todayEarnings ?? this.todayEarnings,
        todayRides: todayRides ?? this.todayRides,
        gpsLost: gpsLost ?? this.gpsLost,
        notice: notice ?? this.notice,
      );
}

/// The driver's session: online / offline, incoming requests and the current job's phases.
///
/// Mock mode (seed data, widget tests, design gallery): requests arrive on a timer (5 s after going
/// online, 8 s after each decline, timeout or completed job) and the vehicle marker moves along each leg.
///
/// Live API ([isLiveApiProvider]): going online needs a GPS fix; offers come from dispatch over the socket
/// ([LiveJobs.offers], plus [LiveJobs.currentOffer] after a reconnect or resume); every job step is an API
/// call; the phone's GPS moves the marker and is uploaded about every 5 s / 20 m (socket, with an HTTP
/// heartbeat every 30 s while the socket is down). ETA comes from progress along the stored route, never
/// from a routing call on a timer.
class DriverSessionController extends Notifier<DriverSessionState> {
  final TripSimulator _sim = TripSimulator(tick: SimTimings.tick);

  // Live API only.
  StreamSubscription<GpsFix>? _gps;
  StreamSubscription<LiveOffer>? _offerSub;
  StreamSubscription<bool>? _connectionSub;
  StreamSubscription<LiveTripUpdate>? _jobSub;
  Timer? _ticker;
  LatLng? _position;
  double _heading = 0;
  DateTime? _lastFixAt;
  LatLng? _lastSent;
  DateTime? _lastSentAt;
  DateTime? _lastHeartbeat;
  int _legMin = 0;
  String? _legKey;
  bool _attached = false;
  final Set<String> _closedOffers = {};

  static const _gpsStaleAfter = Duration(seconds: 30);
  static const _heartbeatEvery = Duration(seconds: 30);

  /// Live position of the driver's vehicle.
  ValueListenable<VehicleFix?> get vehicle => _sim.vehicle;

  /// Latest GPS fix (live API), or null before the first one.
  LatLng? get position => _position;

  bool get _live => ref.read(isLiveApiProvider);
  LiveJobs get _jobs => ref.read(liveJobsProvider);

  @override
  DriverSessionState build() {
    ref.onDispose(_sim.cancelAll);
    ref.watch(mockDatabaseProvider);
    _sim.place(Seed.driverHome);
    if (_live) {
      // A rebuild (log out / log in) starts a fresh session.
      _attached = false;
      _closedOffers.clear();
      _legKey = null;
      ref.onDispose(() {
        _stopTracking();
        _unwatchJob();
      });
      return const DriverSessionState(todayEarnings: 0, todayRides: 0);
    }
    return const DriverSessionState();
  }

  Duration _t(Duration d) => ref.read(simTimingProvider)(d);
  WorkType get workType => ref.read(demoSettingsProvider).workType;

  // ------------------------------------------------------------ online state
  void markSelfieDone() => state = state.copyWith(selfieDoneThisSession: true);

  /// Live API: throws [LocationProblem] (GPS off / denied) or [ApiException] (not approved, plan expired)
  /// with a message to show; the driver stays offline.
  Future<void> goOnline() async {
    if (state.online || state.goingOnline) return;
    if (!_live) {
      state = state.copyWith(online: true, missedRequest: false);
      _scheduleRequest(_t(SimTimings.firstRequest));
      return;
    }
    state = state.copyWith(goingOnline: true, missedRequest: false);
    try {
      final locator = ref.read(driverLocatorProvider);
      final fix = await locator.currentFix();
      await locator.requestNotificationPermission();
      await _jobs.goOnline(fix.point);
      if (!ref.mounted) return;
      _onFix(fix, upload: false);
      state = state.copyWith(online: true, goingOnline: false, gpsLost: false);
      _startTracking();
      unawaited(_recoverOffer());
    } catch (_) {
      if (ref.mounted) state = state.copyWith(goingOnline: false);
      rethrow;
    }
  }

  Future<void> goOffline() async {
    _sim.cancelAll();
    if (!_live) {
      state = state.copyWith(online: false, clearIncoming: true, missedRequest: false);
      return;
    }
    final pending = state.incoming;
    _stopTracking();
    state = state.copyWith(online: false, clearIncoming: true, missedRequest: false, gpsLost: false);
    if (pending != null) _quiet(_jobs.decline(pending.id));
    try {
      await _jobs.goOffline();
    } catch (_) {
      // Dispatch also drops drivers whose heartbeat stops.
    }
  }

  void _scheduleRequest(Duration delay) {
    if (_live) return;
    _sim.after(delay, () {
      if (!state.online || state.onJob || state.incoming != null) return;
      state = state.copyWith(incoming: ref.read(driverRepositoryProvider).nextRequest(workType), missedRequest: false);
    });
  }

  void dismissMissedBanner() => state = state.copyWith(missedRequest: false);

  // ---------------------------------------------------------------- requests
  /// How long the request card stays open: the server's offer time (live) or the 15 s demo countdown.
  Duration get incomingCountdown {
    final expires = state.incomingExpiresAt;
    if (expires == null) return _t(SimTimings.requestCountdown);
    final left = expires.difference(DateTime.now());
    return left < const Duration(seconds: 1) ? const Duration(seconds: 1) : left;
  }

  void declineRequest() {
    final r = state.incoming;
    state = state.copyWith(clearIncoming: true);
    if (_live) {
      if (r != null) {
        _closedOffers.add(r.id);
        _quiet(_jobs.decline(r.id));
      }
      return;
    }
    _scheduleRequest(_t(SimTimings.nextRequest));
  }

  /// The countdown ran out: shows the S-11 banner on D-14. (Live: the server has already moved the
  /// offer to the next driver.)
  void requestTimedOut() {
    final r = state.incoming;
    if (r != null) _closedOffers.add(r.id);
    state = state.copyWith(clearIncoming: true, missedRequest: true);
    _scheduleRequest(_t(SimTimings.nextRequest));
  }

  /// Live API: throws [ApiException] ("This request is no longer available") when another driver got it
  /// or the offer expired; the request is cleared either way.
  Future<void> acceptRequest() async {
    final r = state.incoming;
    if (r == null) return;
    if (!_live) {
      final start = Seed.driverHome;
      final leg = roadPath(start, r.pickup.location, bend: -0.2, mode: travelModeFor(r.vehicle));
      state = state.copyWith(clearIncoming: true, job: r, phase: JobPhase.toPickup, route: leg, etaMin: r.pickupEtaMin);
      _sim.animateAlong(leg, _t(SimTimings.driverLegDuration), onProgress: (p) => _eta(r.pickupEtaMin, p));
      return;
    }
    _closedOffers.add(r.id);
    try {
      final update = await _jobs.accept(r.id);
      if (!ref.mounted) return;
      final job = rideRequestFromUpdate(update, offer: r);
      state = state.copyWith(clearIncoming: true, job: job, phase: JobPhase.toPickup, missedRequest: false);
      _setLeg(_position ?? job.pickup.location, job.pickup.location, job.vehicle, job.pickupEtaMin);
      _watchJob(job.id);
    } on ApiException catch (e) {
      if (ref.mounted) state = state.copyWith(clearIncoming: true);
      if (e.status == 404 || e.status == 409) throw const ApiException(409, 'This request is no longer available');
      rethrow;
    } catch (_) {
      if (ref.mounted) state = state.copyWith(clearIncoming: true);
      rethrow;
    }
  }

  void _eta(int total, double p) {
    final eta = (total * (1 - p)).ceil();
    if (eta != state.etaMin) state = state.copyWith(etaMin: eta);
  }

  // -------------------------------------------------------------------- ride
  /// D-16 "Arrived at pickup" (rides) / D-21 "Reached pickup" (deliveries).
  Future<void> arrivedAtPickup() async {
    final job = state.job;
    if (job == null) return;
    if (_live) {
      await _jobs.arrived(job.id);
      if (ref.mounted) state = state.copyWith(phase: JobPhase.atPickup, etaMin: 0);
      return;
    }
    _sim.cancelAll();
    _sim.place(job.pickup.location);
    state = state.copyWith(phase: JobPhase.atPickup, etaMin: 0);
  }

  /// D-17 (mock only): true if [code] matches the ride OTP (4829). With the live API the server checks it
  /// in [startTrip].
  bool verifyRideOtp(String code) => code == (state.job?.otp ?? Seed.rideOtp);

  /// D-17 "Start ride" with the passenger's [otp] / D-21 "Picked up". Live API: throws [ApiException]
  /// ("Wrong OTP, please try again") when the server rejects the code.
  Future<void> startTrip({String? otp}) async {
    final job = state.job;
    if (job == null) return;
    if (_live) {
      await _jobs.start(job.id, otp: job.isDelivery ? null : otp);
      if (!ref.mounted) return;
      state = state.copyWith(phase: JobPhase.toDrop);
      _setLeg(job.pickup.location, job.drop.location, job.vehicle, job.tripMin);
      return;
    }
    final leg = roadPath(job.pickup.location, job.drop.location, mode: travelModeFor(job.vehicle));
    state = state.copyWith(phase: JobPhase.toDrop, route: leg, etaMin: job.tripMin);
    _sim.animateAlong(leg, _t(SimTimings.rideDuration), onProgress: (p) => _eta(job.tripMin, p));
  }

  /// D-18 "Swipe to end ride" → collect payment. Live API: completes the trip (the fare is recorded).
  Future<void> endRide() async {
    final job = state.job;
    if (job == null) return;
    if (_live) {
      await _jobs.complete(job.id);
      if (!ref.mounted) return;
      _unwatchJob();
      state = state.copyWith(phase: JobPhase.collect, etaMin: 0);
      return;
    }
    _sim.cancelAll();
    _sim.place(job.drop.location);
    state = state.copyWith(phase: JobPhase.collect, etaMin: 0);
  }

  // ---------------------------------------------------------------- delivery
  /// D-21 "Reached drop location" → D-22a (a local step in both modes).
  void reachedDrop() {
    final job = state.job;
    if (job == null) return;
    if (!_live) {
      _sim.cancelAll();
      _sim.place(job.drop.location);
    }
    state = state.copyWith(phase: JobPhase.atDrop, etaMin: 0);
  }

  /// D-22a (mock only): true if [code] matches the delivery OTP (7153).
  bool verifyDeliveryOtp(String code) => code == (state.job?.parcel?.deliveryOtp ?? Seed.deliveryOtp);

  /// D-22a "Complete delivery" → collect view. Live API: the server checks the receiver's [otp] and
  /// throws [ApiException] when it is wrong.
  Future<void> completeDelivery({String? otp}) async {
    final job = state.job;
    if (job == null) return;
    if (_live) {
      await _jobs.complete(job.id, otp: otp);
      if (!ref.mounted) return;
      _unwatchJob();
    }
    state = state.copyWith(phase: JobPhase.collect);
  }

  // ------------------------------------------------------------------ finish
  /// D-19 / D-22b "Received cash" / "Received on UPI": today's earnings and rides go up by the fare and
  /// the driver is back online (mock: the next request arrives in 8 s; live: the API already recorded
  /// the fare, so earnings are reloaded).
  Future<void> collectPayment(PaymentMode mode) async {
    final job = state.job;
    if (job == null) return;
    if (_live) {
      _unwatchJob();
      ref.read(realtimeProvider).leaveTrip(job.id);
      state = state.copyWith(
        clearJob: true,
        phase: JobPhase.none,
        route: const [],
        etaMin: 0,
        todayEarnings: state.todayEarnings + job.fare,
        todayRides: state.todayRides + 1,
      );
      ref.invalidate(earningsProvider);
      unawaited(refreshToday());
      unawaited(_recoverOffer());
      return;
    }
    final now = RidoClock.now();
    await ref.read(driverRepositoryProvider).recordCompletedJob(EarningsTrip(
          id: 'e${now.millisecondsSinceEpoch}',
          time: now,
          from: job.pickup.name.split(' ').first,
          to: job.drop.name.split(' ').first,
          fare: job.fare,
          paymentMode: mode,
          distanceKm: job.tripKm,
          durationMin: job.tripMin,
          passengerName: job.customerName,
          isDelivery: job.isDelivery,
        ));
    state = state.copyWith(
      clearJob: true,
      phase: JobPhase.none,
      route: const [],
      todayEarnings: state.todayEarnings + job.fare,
      todayRides: state.todayRides + 1,
      online: true,
    );
    ref.invalidate(earningsProvider);
    _scheduleRequest(_t(SimTimings.nextRequest));
  }

  /// D-16 overflow → Cancel ride → reason. Back to D-14 online. Live API: throws when the API refuses.
  Future<void> cancelJob({String? reason}) async {
    final job = state.job;
    if (_live) {
      if (job != null) await _jobs.cancel(job.id, reason: reason);
      if (!ref.mounted) return;
      _endJob();
      return;
    }
    _sim.cancelAll();
    state = state.copyWith(clearJob: true, phase: JobPhase.none, route: const []);
    _scheduleRequest(_t(SimTimings.nextRequest));
  }

  // ------------------------------------------------------------- live API only
  /// Restores the session when Home opens (live API): today's earnings, the job the driver was on
  /// (after an app restart) and, if the API still has the driver online, the online state.
  Future<void> attach() async {
    if (!_live || _attached) return;
    if (!ref.read(driverRepositoryProvider).isLoggedIn) return;
    _attached = true;
    unawaited(refreshToday());
    try {
      final active = await _jobs.active();
      if (!ref.mounted) return;
      if (active != null && jobPhaseForStatus(active.status) != JobPhase.none) {
        await _restoreJob(active);
        return;
      }
      final me = await ref.read(apiClientProvider).get('/drivers/me');
      if (!ref.mounted || state.online) return;
      if (me is Map && me['isOnline'] == true) await _resumeOnline();
    } catch (_) {
      _attached = false; // Try again the next time Home opens.
    }
  }

  /// App back in the foreground: reconnect, pick up an offer missed meanwhile and check the job.
  void onAppResumed() {
    if (!_live || !state.online) return;
    ref.read(realtimeProvider).connect();
    unawaited(_recoverOffer());
    unawaited(_syncJob());
  }

  /// Today's earnings and rides for the Home card.
  Future<void> refreshToday() async {
    if (!_live) return;
    try {
      final s = await ref.read(driverRepositoryProvider).earnings(EarningsPeriod.today);
      if (ref.mounted) state = state.copyWith(todayEarnings: s.total, todayRides: s.rides);
    } catch (_) {
      // Keep the last numbers.
    }
  }

  Future<void> _restoreJob(LiveTripUpdate update) async {
    final phase = jobPhaseForStatus(update.status);
    final job = rideRequestFromUpdate(update);
    state = state.copyWith(online: true, job: job, phase: phase, selfieDoneThisSession: true);
    _watchJob(job.id);
    try {
      _onFix(await ref.read(driverLocatorProvider).currentFix(), upload: false);
    } catch (_) {
      // The stream below retries; the job screens still work without a fix.
    }
    if (!ref.mounted) return;
    _startTracking();
    switch (phase) {
      case JobPhase.toPickup:
        _setLeg(_position ?? job.pickup.location, job.pickup.location, job.vehicle, 0);
      case JobPhase.toDrop || JobPhase.atDrop:
        _setLeg(job.pickup.location, job.drop.location, job.vehicle, job.tripMin);
      case JobPhase.none || JobPhase.atPickup || JobPhase.collect:
        break;
    }
  }

  /// The API still had the driver online (app killed): resume silently when GPS needs no prompt,
  /// otherwise tell the API the driver is offline.
  Future<void> _resumeOnline() async {
    if (await ref.read(driverLocatorProvider).isReadyWithoutPrompt()) {
      try {
        await goOnline();
        if (ref.mounted) state = state.copyWith(selfieDoneThisSession: true);
        return;
      } catch (_) {
        // Fall through.
      }
    }
    _quiet(_jobs.goOffline());
  }

  void _startTracking() {
    _stopTracking();
    _gps = ref.read(driverLocatorProvider).positions().listen(_onFix, onError: (Object _) {});
    _offerSub = _jobs.offers().listen(_onOffer, onError: (Object _) {});
    _connectionSub = ref.read(realtimeProvider).connection.listen((up) {
      if (!up) return;
      unawaited(_recoverOffer());
      unawaited(_syncJob());
    });
    _ticker = Timer.periodic(const Duration(seconds: 10), (_) => _tick());
  }

  void _stopTracking() {
    _gps?.cancel();
    _offerSub?.cancel();
    _connectionSub?.cancel();
    _ticker?.cancel();
    _gps = null;
    _offerSub = null;
    _connectionSub = null;
    _ticker = null;
  }

  void _onFix(GpsFix fix, {bool upload = true}) {
    final prev = _position;
    final p = fix.point;
    _position = p;
    _lastFixAt = DateTime.now();
    if (fix.heading != null) {
      _heading = fix.heading!;
    } else if (prev != null && const Distance().as(LengthUnit.Meter, prev, p) > 5) {
      _heading = const Distance().bearing(prev, p);
    }
    _sim.place(p, heading: _heading);
    if (!ref.mounted) return;
    if (state.gpsLost) state = state.copyWith(gpsLost: false);
    final now = DateTime.now();
    if (upload && shouldSendFix(last: _lastSent, lastAt: _lastSentAt, next: p, now: now)) {
      if (ref.read(realtimeProvider).isConnected) {
        _jobs.sendLocation(p);
        _lastSent = p;
        _lastSentAt = now;
      }
    }
    _updateEta();
  }

  void _updateEta() {
    final p = _position;
    if (p == null || !state.onJob || state.route.length < 2) return;
    if (state.phase != JobPhase.toPickup && state.phase != JobPhase.toDrop) return;
    final eta = etaAlong(state.route, p, _legMin);
    if (eta != state.etaMin) state = state.copyWith(etaMin: eta);
  }

  /// Every 10 s while online: GPS-lost flag (S-16) and the HTTP heartbeat while the socket is down.
  void _tick() {
    if (!ref.mounted || !state.online) return;
    final now = DateTime.now();
    final stale = _lastFixAt == null || now.difference(_lastFixAt!) > _gpsStaleAfter;
    if (stale != state.gpsLost) state = state.copyWith(gpsLost: stale);
    final realtime = ref.read(realtimeProvider);
    if (realtime.isConnected) return;
    realtime.connect();
    final p = _position;
    if (p != null && (_lastHeartbeat == null || now.difference(_lastHeartbeat!) >= _heartbeatEvery)) {
      _lastHeartbeat = now;
      _quiet(_jobs.heartbeat(p));
    }
  }

  void _onOffer(LiveOffer offer) {
    if (!ref.mounted) return;
    final id = offer.request.id;
    if (!state.online || state.onJob || _closedOffers.contains(id) || state.incoming?.id == id) return;
    state = state.copyWith(
      incoming: offer.request,
      incomingExpiresAt: DateTime.now().add(Duration(seconds: offer.expiresInSeconds)),
      missedRequest: false,
    );
  }

  /// An offer that arrived while the socket was reconnecting (or the app was in the background).
  Future<void> _recoverOffer() async {
    if (!_live || !state.online || state.onJob || state.incoming != null) return;
    try {
      final offer = await _jobs.currentOffer();
      if (offer != null) _onOffer(offer);
    } catch (_) {
      // The socket delivers the next one.
    }
  }

  /// After a reconnect: the job may have been cancelled while the socket was down.
  Future<void> _syncJob() async {
    final job = state.job;
    if (job == null || state.phase == JobPhase.collect) return;
    try {
      final active = await _jobs.active();
      if (!ref.mounted || state.job?.id != job.id || state.phase == JobPhase.collect) return;
      if (active == null || active.trip.id != job.id || active.status == 'CANCELLED') {
        _endJob(notice: _cancelledNotice(job));
      }
    } catch (_) {
      // Checked again on the next reconnect.
    }
  }

  void _watchJob(String tripId) {
    _jobSub?.cancel();
    _jobSub = _jobs.updates(tripId).listen((u) {
      final job = state.job;
      if (!ref.mounted || job == null || u.trip.id != job.id) return;
      if (u.status == 'CANCELLED' && state.phase != JobPhase.collect) _endJob(notice: _cancelledNotice(job));
    }, onError: (Object _) {});
  }

  void _unwatchJob() {
    _jobSub?.cancel();
    _jobSub = null;
  }

  SessionNotice _cancelledNotice(RideRequest job) => SessionNotice(
        job.isDelivery ? 'The sender cancelled this delivery' : '${job.customerName.split(' ').first} cancelled the ride',
        jobEnded: true,
      );

  void _endJob({SessionNotice? notice}) {
    final job = state.job;
    _unwatchJob();
    if (job != null) ref.read(realtimeProvider).leaveTrip(job.id);
    _legKey = null;
    state = state.copyWith(clearJob: true, phase: JobPhase.none, route: const [], etaMin: 0, notice: notice);
    unawaited(_recoverOffer());
  }

  /// Draws the leg [from] → [to] now (curved stand-in or cached road) and swaps in the road route once
  /// it arrives. One routing call per leg (cost rule).
  void _setLeg(LatLng from, LatLng to, VehicleKind vehicle, int minutes) {
    final mode = travelModeFor(vehicle);
    final key = '${from.latitude},${from.longitude}|${to.latitude},${to.longitude}';
    _legKey = key;
    final route = roadPath(from, to, mode: mode);
    _legMin = minutes > 0 ? minutes : estimateMinutes(routeKm(route));
    state = state.copyWith(route: route, etaMin: _legMin);
    _updateEta();
    RoadRouter.fetch(from, to, mode: mode).then((road) {
      if (road == null || road.length < 2 || !ref.mounted || _legKey != key) return;
      state = state.copyWith(route: road);
      _updateEta();
    }, onError: (Object _) {});
  }

  static void _quiet(Future<void> f) => f.then((_) {}, onError: (Object _) {});
}

final driverSessionProvider =
    NotifierProvider<DriverSessionController, DriverSessionState>(DriverSessionController.new);

/// Earnings for the Today / Week / Month tabs.
final earningsProvider = FutureProvider.family<EarningsSummary, EarningsPeriod>((ref, period) {
  ref.watch(mockDatabaseProvider);
  ref.watch(demoSettingsProvider.select((s) => (s.emptyEarnings, s.offline, s.slowLoading)));
  return ref.watch(driverRepositoryProvider).earnings(period);
});
