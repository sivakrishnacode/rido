// The live (API) branch of DriverSessionController against fake LiveJobs / realtime / GPS: going online
// needs a fix, offers become the request card with the server's countdown, accept / arrived / start
// (server-checked OTP) / complete, GPS uploads, a passenger cancellation, and errors from the API.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_driver/state/driver_location.dart';
import 'package:rido_driver/state/driver_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _here = LatLng(11.0168, 76.9558);

LiveTripUpdate _update(String id, String status) {
  final r = Seed.rideRequest;
  return LiveTripUpdate(
    Trip(
      id: id,
      kind: TripKind.ride,
      vehicle: VehicleKind.bike,
      pickup: r.pickup,
      drop: r.drop,
      fare: 64,
      status: TripStatus.driverAssigned,
      startedAt: DateTime(2026, 9, 26),
      distanceKm: 6,
      durationMin: 20,
      otp: '',
    ),
    status,
    {
      'id': id,
      'status': status,
      'passenger': {'name': 'Priya', 'phone': '+919876543210'},
    },
  );
}

class FakeRealtime extends RealtimeClient {
  FakeRealtime(super.api);
  final sent = <LatLng>[];
  bool connected = true;

  @override
  bool get isConnected => connected;
  @override
  Stream<bool> get connection => const Stream.empty();
  @override
  void connect() {}
  @override
  void leaveTrip(String tripId) {}
  @override
  Future<bool> joinTrip(String tripId) async => true;
  @override
  void sendLocation(double lat, double lng) => sent.add(LatLng(lat, lng));
}

class FakeJobs extends LiveJobs {
  FakeJobs(super.api, super.realtime);

  final offersCtl = StreamController<LiveOffer>.broadcast();
  final updatesCtl = StreamController<LiveTripUpdate>.broadcast();
  final calls = <String>[];
  Object? onlineError;
  Object? acceptError;

  @override
  Future<void> goOnline(LatLng at) async {
    calls.add('online');
    if (onlineError != null) throw onlineError!;
  }

  @override
  Future<void> goOffline() async => calls.add('offline');
  @override
  Stream<LiveOffer> offers() => offersCtl.stream;
  @override
  Future<LiveOffer?> currentOffer() async => null;
  @override
  Stream<LiveTripUpdate> updates(String tripId) => updatesCtl.stream.where((u) => u.trip.id == tripId);

  @override
  Future<LiveTripUpdate> accept(String tripId) async {
    calls.add('accept');
    if (acceptError != null) throw acceptError!;
    return _update(tripId, 'DRIVER_ASSIGNED');
  }

  @override
  Future<void> decline(String tripId) async => calls.add('decline');

  @override
  Future<LiveTripUpdate> arrived(String tripId) async {
    calls.add('arrived');
    return _update(tripId, 'DRIVER_ARRIVED');
  }

  @override
  Future<LiveTripUpdate> start(String tripId, {String? otp}) async {
    calls.add('start:$otp');
    if (otp != '1234') throw const ApiException(400, 'Wrong OTP, please try again');
    return _update(tripId, 'IN_PROGRESS');
  }

  @override
  Future<LiveTripUpdate> complete(String tripId, {String? otp}) async {
    calls.add('complete');
    return _update(tripId, 'COMPLETED');
  }

  @override
  Future<LiveTripUpdate> cancel(String tripId, {String? reason}) async {
    calls.add('cancel:$reason');
    return _update(tripId, 'CANCELLED');
  }

  @override
  Future<LiveTripUpdate?> active() async => null;
  @override
  Future<void> heartbeat(LatLng p) async => calls.add('heartbeat');
}

class FakeLocator extends DriverLocator {
  final fixes = StreamController<GpsFix>.broadcast();
  Object? problem;

  @override
  Future<GpsFix> currentFix() async {
    if (problem != null) throw problem!;
    return GpsFix(_here, at: DateTime.now());
  }

  @override
  Future<void> requestNotificationPermission() async {}
  @override
  Stream<GpsFix> positions() => fixes.stream;
  @override
  Future<bool> isReadyWithoutPrompt() async => true;
}

LiveOffer _offer(String id, {int seconds = 15}) => LiveOffer(
      Seed.rideRequest.copyWith(id: id, customerName: 'Priya', customerPhone: '+919876543210', otp: ''),
      seconds,
    );

void main() {
  late FakeJobs jobs;
  late FakeRealtime realtime;
  late FakeLocator locator;
  late ProviderContainer container;

  DriverSessionController session() => container.read(driverSessionProvider.notifier);
  DriverSessionState state() => container.read(driverSessionProvider);

  setUp(() async {
    RoadRouter.enabled = false;
    SharedPreferences.setMockInitialValues({});
    final api = ApiClient(baseUrl: 'http://localhost:1/v1', session: ApiSession(await SharedPreferences.getInstance()));
    realtime = FakeRealtime(api);
    jobs = FakeJobs(api, realtime);
    locator = FakeLocator();
    container = ProviderContainer(overrides: [
      isLiveApiProvider.overrideWithValue(true),
      apiClientProvider.overrideWithValue(api),
      realtimeProvider.overrideWithValue(realtime),
      liveJobsProvider.overrideWithValue(jobs),
      driverLocatorProvider.overrideWithValue(locator),
    ]);
    // Keep the provider alive between reads.
    container.listen(driverSessionProvider, (_, _) {});
  });

  tearDown(() => container.dispose());

  test('live state starts with no seed earnings', () {
    expect(state().todayEarnings, 0);
    expect(state().todayRides, 0);
  });

  test('going online needs a GPS fix; a location problem keeps the driver offline', () async {
    locator.problem = const LocationProblem('Turn on Location to go online');
    await expectLater(session().goOnline(), throwsA(isA<LocationProblem>()));
    expect(state().online, isFalse);
    expect(state().goingOnline, isFalse);
    expect(jobs.calls, isEmpty);
  });

  test('an API refusal (plan expired) keeps the driver offline with the message', () async {
    jobs.onlineError = const ApiException(403, 'Plan expired. Renew to go online again');
    await expectLater(
      session().goOnline(),
      throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Plan expired. Renew to go online again')),
    );
    expect(state().online, isFalse);
  });

  test('ride: offer → accept → arrived → wrong OTP → start → complete → collect', () async {
    await session().goOnline();
    expect(state().online, isTrue);
    expect(jobs.calls, ['online']);

    jobs.offersCtl.add(_offer('t1', seconds: 12));
    await pumpEventQueue();
    expect(state().incoming?.id, 't1');
    expect(session().incomingCountdown.inSeconds, inInclusiveRange(10, 12));

    await session().acceptRequest();
    expect(state().incoming, isNull);
    expect(state().job?.id, 't1');
    expect(state().job?.customerPhone, '+919876543210');
    expect(state().phase, JobPhase.toPickup);
    expect(state().route, isNotEmpty);

    // Another offer while on a job is ignored.
    jobs.offersCtl.add(_offer('t2'));
    await pumpEventQueue();
    expect(state().incoming, isNull);

    await session().arrivedAtPickup();
    expect(state().phase, JobPhase.atPickup);

    await expectLater(
      session().startTrip(otp: '9999'),
      throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Wrong OTP, please try again')),
    );
    expect(state().phase, JobPhase.atPickup);

    await session().startTrip(otp: '1234');
    expect(state().phase, JobPhase.toDrop);
    expect(state().etaMin, greaterThan(0));

    await session().endRide();
    expect(state().phase, JobPhase.collect);

    await session().collectPayment(PaymentMode.cash);
    expect(state().job, isNull);
    expect(state().online, isTrue);
    expect(jobs.calls, ['online', 'accept', 'arrived', 'start:9999', 'start:1234', 'complete']);
  });

  test('GPS fixes move the marker and go up over the socket (throttled)', () async {
    await session().goOnline();
    final next = offsetPoint(_here, 50, 0);
    locator.fixes.add(GpsFix(next, at: DateTime.now()));
    await pumpEventQueue();
    expect(session().vehicle.value?.position, next);
    expect(realtime.sent, [next]);
    // A second fix right away is not uploaded.
    locator.fixes.add(GpsFix(offsetPoint(next, 5, 0), at: DateTime.now()));
    await pumpEventQueue();
    expect(realtime.sent, hasLength(1));
  });

  test('decline and timeout clear the card; a timed-out offer is not shown again', () async {
    await session().goOnline();
    jobs.offersCtl.add(_offer('t1'));
    await pumpEventQueue();
    session().declineRequest();
    expect(state().incoming, isNull);
    await pumpEventQueue();
    expect(jobs.calls.last, 'decline');

    jobs.offersCtl.add(_offer('t2'));
    await pumpEventQueue();
    session().requestTimedOut();
    expect(state().missedRequest, isTrue);
    jobs.offersCtl.add(_offer('t2'));
    await pumpEventQueue();
    expect(state().incoming, isNull);
  });

  test('accepting a request someone else took clears it with a clear message', () async {
    await session().goOnline();
    jobs.acceptError = const ApiException(409, 'Trip is not open');
    jobs.offersCtl.add(_offer('t1'));
    await pumpEventQueue();
    await expectLater(
      session().acceptRequest(),
      throwsA(isA<ApiException>().having((e) => e.message, 'message', 'This request is no longer available')),
    );
    expect(state().incoming, isNull);
    expect(state().job, isNull);
  });

  test('the passenger cancelling ends the job with a notice', () async {
    await session().goOnline();
    jobs.offersCtl.add(_offer('t1'));
    await pumpEventQueue();
    await session().acceptRequest();
    jobs.updatesCtl.add(_update('t1', 'CANCELLED'));
    await pumpEventQueue();
    expect(state().job, isNull);
    expect(state().phase, JobPhase.none);
    expect(state().notice?.jobEnded, isTrue);
    expect(state().notice?.message, 'Priya cancelled the ride');
  });

  test('the driver cancelling calls the API with the reason', () async {
    await session().goOnline();
    jobs.offersCtl.add(_offer('t1'));
    await pumpEventQueue();
    await session().acceptRequest();
    await session().cancelJob(reason: 'Vehicle problem');
    expect(state().job, isNull);
    expect(jobs.calls.last, 'cancel:Vehicle problem');
  });

  test('going offline stops offers and tells the API', () async {
    await session().goOnline();
    await session().goOffline();
    expect(state().online, isFalse);
    expect(jobs.calls.last, 'offline');
    jobs.offersCtl.add(_offer('t1'));
    await pumpEventQueue();
    expect(state().incoming, isNull);
  });
}
