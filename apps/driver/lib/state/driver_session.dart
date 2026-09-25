import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rido_data/rido_data.dart';

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

@immutable
class DriverSessionState {
  const DriverSessionState({
    this.online = false,
    this.selfieDoneThisSession = false,
    this.incoming,
    this.missedRequest = false,
    this.job,
    this.phase = JobPhase.none,
    this.route = const [],
    this.etaMin = 0,
    this.todayEarnings = Seed.todayEarnings,
    this.todayRides = Seed.todayRides,
  });

  final bool online;

  /// The daily selfie check (S-13) is due the first time each app session.
  final bool selfieDoneThisSession;

  /// A request waiting for Accept / Decline (D-15 / D-20).
  final RideRequest? incoming;

  /// Show the S-11 "You missed a ride request" banner on D-14.
  final bool missedRequest;
  final RideRequest? job;
  final JobPhase phase;

  /// Polyline for the current leg (to pickup, then to drop).
  final List<LatLng> route;
  final int etaMin;
  final int todayEarnings;
  final int todayRides;

  bool get onJob => job != null && phase != JobPhase.none;

  DriverSessionState copyWith({
    bool? online,
    bool? selfieDoneThisSession,
    RideRequest? incoming,
    bool clearIncoming = false,
    bool? missedRequest,
    RideRequest? job,
    bool clearJob = false,
    JobPhase? phase,
    List<LatLng>? route,
    int? etaMin,
    int? todayEarnings,
    int? todayRides,
  }) =>
      DriverSessionState(
        online: online ?? this.online,
        selfieDoneThisSession: selfieDoneThisSession ?? this.selfieDoneThisSession,
        incoming: clearIncoming ? null : (incoming ?? this.incoming),
        missedRequest: missedRequest ?? this.missedRequest,
        job: clearJob ? null : (job ?? this.job),
        phase: phase ?? this.phase,
        route: route ?? this.route,
        etaMin: etaMin ?? this.etaMin,
        todayEarnings: todayEarnings ?? this.todayEarnings,
        todayRides: todayRides ?? this.todayRides,
      );
}

/// Drives the driver side of the prototype: online / offline, incoming requests on a timer
/// (5 s after going online, 8 s after each decline, timeout or completed job), and the
/// current job's phases. The vehicle marker moves along each leg.
class DriverSessionController extends Notifier<DriverSessionState> {
  final TripSimulator _sim = TripSimulator(tick: SimTimings.tick);

  /// Live position of the driver's vehicle.
  ValueListenable<VehicleFix?> get vehicle => _sim.vehicle;

  @override
  DriverSessionState build() {
    ref.onDispose(_sim.cancelAll);
    ref.watch(mockDatabaseProvider);
    _sim.place(Seed.driverHome);
    return const DriverSessionState();
  }

  Duration _t(Duration d) => ref.read(simTimingProvider)(d);
  WorkType get workType => ref.read(demoSettingsProvider).workType;

  // ------------------------------------------------------------ online state
  void markSelfieDone() => state = state.copyWith(selfieDoneThisSession: true);

  void goOnline() {
    if (state.online) return;
    state = state.copyWith(online: true, missedRequest: false);
    _scheduleRequest(_t(SimTimings.firstRequest));
  }

  void goOffline() {
    _sim.cancelAll();
    state = state.copyWith(online: false, clearIncoming: true, missedRequest: false);
  }

  void _scheduleRequest(Duration delay) {
    _sim.after(delay, () {
      if (!state.online || state.onJob || state.incoming != null) return;
      state = state.copyWith(incoming: ref.read(driverRepositoryProvider).nextRequest(workType), missedRequest: false);
    });
  }

  void dismissMissedBanner() => state = state.copyWith(missedRequest: false);

  // ---------------------------------------------------------------- requests
  void declineRequest() {
    state = state.copyWith(clearIncoming: true);
    _scheduleRequest(_t(SimTimings.nextRequest));
  }

  /// The 15 s countdown ran out: shows the S-11 banner on D-14.
  void requestTimedOut() {
    state = state.copyWith(clearIncoming: true, missedRequest: true);
    _scheduleRequest(_t(SimTimings.nextRequest));
  }

  void acceptRequest() {
    final r = state.incoming;
    if (r == null) return;
    final start = Seed.driverHome;
    final leg = roadPath(start, r.pickup.location, bend: -0.2);
    state = state.copyWith(clearIncoming: true, job: r, phase: JobPhase.toPickup, route: leg, etaMin: r.pickupEtaMin);
    _sim.animateAlong(leg, _t(SimTimings.driverLegDuration), onProgress: (p) => _eta(r.pickupEtaMin, p));
  }

  void _eta(int total, double p) {
    final eta = (total * (1 - p)).ceil();
    if (eta != state.etaMin) state = state.copyWith(etaMin: eta);
  }

  // -------------------------------------------------------------------- ride
  /// D-16 "Arrived at pickup" (rides) / D-21 "Reached pickup" (deliveries).
  void arrivedAtPickup() {
    final job = state.job;
    if (job == null) return;
    _sim.cancelAll();
    _sim.place(job.pickup.location);
    state = state.copyWith(phase: JobPhase.atPickup, etaMin: 0);
  }

  /// D-17: true if [code] matches the ride OTP (4829).
  bool verifyRideOtp(String code) => code == (state.job?.otp ?? Seed.rideOtp);

  /// D-17 "Start ride" (after a correct OTP) / D-21 "Picked up".
  void startTrip() {
    final job = state.job;
    if (job == null) return;
    final leg = roadPath(job.pickup.location, job.drop.location);
    state = state.copyWith(phase: JobPhase.toDrop, route: leg, etaMin: job.tripMin);
    _sim.animateAlong(leg, _t(SimTimings.rideDuration), onProgress: (p) => _eta(job.tripMin, p));
  }

  /// D-18 "Swipe to end ride" → collect payment.
  void endRide() {
    final job = state.job;
    if (job == null) return;
    _sim.cancelAll();
    _sim.place(job.drop.location);
    state = state.copyWith(phase: JobPhase.collect, etaMin: 0);
  }

  // ---------------------------------------------------------------- delivery
  /// D-21 "Reached drop location" → D-22a.
  void reachedDrop() {
    final job = state.job;
    if (job == null) return;
    _sim.cancelAll();
    _sim.place(job.drop.location);
    state = state.copyWith(phase: JobPhase.atDrop, etaMin: 0);
  }

  /// D-22a: true if [code] matches the delivery OTP (7153).
  bool verifyDeliveryOtp(String code) => code == (state.job?.parcel?.deliveryOtp ?? Seed.deliveryOtp);

  /// D-22a "Complete delivery" → collect view.
  void completeDelivery() => state = state.copyWith(phase: JobPhase.collect);

  // ------------------------------------------------------------------ finish
  /// D-19 / D-22b "Received cash" / "Received on UPI": today's earnings and rides go up by
  /// the fare, the driver is back online and the next request arrives in 8 s.
  Future<void> collectPayment(PaymentMode mode) async {
    final job = state.job;
    if (job == null) return;
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

  /// D-16 overflow → Cancel ride → reason. Back to D-14 online.
  void cancelJob() {
    _sim.cancelAll();
    state = state.copyWith(clearJob: true, phase: JobPhase.none, route: const []);
    _scheduleRequest(_t(SimTimings.nextRequest));
  }
}

final driverSessionProvider =
    NotifierProvider<DriverSessionController, DriverSessionState>(DriverSessionController.new);

/// Earnings for the Today / Week / Month tabs.
final earningsProvider = FutureProvider.family<EarningsSummary, EarningsPeriod>((ref, period) {
  ref.watch(mockDatabaseProvider);
  ref.watch(demoSettingsProvider.select((s) => (s.emptyEarnings, s.offline, s.slowLoading)));
  return ref.watch(driverRepositoryProvider).earnings(period);
});
