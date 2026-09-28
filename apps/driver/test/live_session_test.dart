// The live (API) branch of DriverSessionController against fake LiveJobs / realtime / GPS: going online
// needs a fix, offers become the request card with the server's countdown, accept / arrived / start
// (server-checked OTP) / complete, GPS uploads, a passenger cancellation, and errors from the API.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:go_router/go_router.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_driver/app.dart';
import 'package:rido_driver/state/driver_location.dart';
import 'package:rido_driver/state/driver_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _here = LatLng(11.0168, 76.9558);

LiveTripUpdate _update(String id, String status, {Map<String, Object?> extra = const {}}) {
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
      ...extra,
      'id': id,
      'status': status,
      'passenger': {'name': 'Priya', 'phone': '+919876543210'},
    },
  );
}

class FakeRealtime extends RealtimeClient {
  FakeRealtime(super.api);
  final sent = <LatLng>[];
  final payloads = <Map<String, Object>>[];
  final batches = <List<Map<String, Object>>>[];
  bool connected = true;
  bool batchAck = true;
  final connectionCtl = StreamController<bool>.broadcast();

  @override
  bool get isConnected => connected;
  @override
  Stream<bool> get connection => connectionCtl.stream;
  @override
  void connect() {}
  @override
  void leaveTrip(String tripId) {}
  @override
  Future<bool> joinTrip(String tripId) async => true;
  @override
  void sendLocation(Map<String, Object> fix) {
    payloads.add(fix);
    sent.add(LatLng(fix['lat']! as double, fix['lng']! as double));
  }

  @override
  Future<bool> sendLocations(List<Map<String, Object>> fixes) async {
    batches.add(fixes);
    return batchAck;
  }
}

class FakeJobs extends LiveJobs {
  FakeJobs(super.api, super.realtime);

  final offersCtl = StreamController<LiveOffer>.broadcast();
  final updatesCtl = StreamController<LiveTripUpdate>.broadcast();
  final nudgesCtl = StreamController<TripNudge>.broadcast();
  @override
  Stream<TripNudge> nudges(String tripId) => nudgesCtl.stream.where((n) => n.tripId == tripId);
  final calls = <String>[];
  Object? onlineError;
  Object? acceptError;

  /// Refuse arrived / complete without a far reason (the API's 422 TOO_FAR).
  bool tooFar = false;
  final positions = <LatLng?>[];

  static ApiException _tooFar(String stop, int metres) => ApiException(
        422,
        "You're $metres m from the $stop point",
        code: 'TOO_FAR',
        details: {'stop': stop, 'distanceM': metres, 'radiusM': stop == 'pickup' ? 250 : 400, 'reasons': ['GPS is wrong', 'Passenger moved']},
      );

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
  Future<LiveTripUpdate> arrived(String tripId, {LatLng? at, String? farReason}) async {
    positions.add(at);
    if (tooFar && farReason == null) throw _tooFar('pickup', 850);
    calls.add(farReason == null ? 'arrived' : 'arrived:$farReason');
    return _update(tripId, 'DRIVER_ARRIVED');
  }

  @override
  Future<LiveTripUpdate> start(String tripId, {String? otp}) async {
    calls.add('start:$otp');
    if (otp != '1234') throw const ApiException(400, 'Wrong OTP, please try again');
    return _update(tripId, 'IN_PROGRESS');
  }

  @override
  Future<LiveTripUpdate> complete(String tripId, {String? otp, LatLng? at, String? farReason}) async {
    positions.add(at);
    if (otp != null && otp != '5678') throw const ApiException(400, 'Wrong OTP, please try again');
    if (tooFar && farReason == null) throw _tooFar('drop', 1200);
    calls.add(farReason == null ? 'complete' : 'complete:$farReason');
    return _update(tripId, 'COMPLETED');
  }

  @override
  Future<LiveTripUpdate> cancel(String tripId, {CancelCode code = CancelCode.other, String? note}) async {
    calls.add('cancel:${code.api}');
    return _update(tripId, 'CANCELLED');
  }

  @override
  Future<LiveTripUpdate?> active() async => null;
  @override
  Future<void> heartbeat(DriverFix fix) async => calls.add('heartbeat');
}

class FakeLocator extends DriverLocator {
  final fixes = StreamController<GpsFix>.broadcast();
  Object? problem;
  LocationAccess accessResult = LocationAccess.granted;
  int asked = 0;

  @override
  Future<LocationAccess> access({bool ask = false}) async {
    if (ask) asked++;
    return accessResult;
  }

  @override
  Future<GpsFix?> lastKnownFix() async => GpsFix(offsetPoint(_here, 300, 90), at: DateTime.now());

  int currentFixCalls = 0;

  @override
  Future<GpsFix> currentFix() async {
    currentFixCalls++;
    if (problem != null) throw problem!;
    return GpsFix(_here, at: DateTime.now());
  }

  @override
  Future<void> ensureReady() async {
    if (problem != null) throw problem!;
  }

  @override
  Future<void> requestNotificationPermission() async {}
  int gpsListens = 0;
  @override
  Stream<GpsFix> positions() {
    gpsListens++;
    return fixes.stream;
  }
  final previewFixes = StreamController<GpsFix>.broadcast();
  @override
  Stream<GpsFix> previewPositions() => previewFixes.stream;
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

  test('fixes carry time, accuracy, speed, heading and the mock flag', () async {
    await session().goOnline();
    final at = DateTime.fromMillisecondsSinceEpoch(1800000000000);
    locator.fixes.add(GpsFix(offsetPoint(_here, 50, 0), at: at, accuracy: 6.44, speed: 7.5, heading: 92.26, isMocked: true));
    await pumpEventQueue();
    expect(realtime.payloads.single, {
      'lat': realtime.sent.single.latitude,
      'lng': realtime.sent.single.longitude,
      'ts': 1800000000000,
      'acc': 6.4,
      'spd': 7.5,
      'hdg': 92.3,
      'mock': true,
    });
  });

  test('socket down: fixes are buffered, then flushed as one batch on reconnect (kept if the flush fails)', () async {
    await session().goOnline();
    realtime.connected = false;
    final next = offsetPoint(_here, 100, 0);
    locator.fixes.add(GpsFix(next, at: DateTime.now(), accuracy: 5));
    await pumpEventQueue();
    expect(realtime.sent, isEmpty, reason: 'nothing goes up while the socket is down');

    realtime.batchAck = false;
    realtime.connected = true;
    realtime.connectionCtl.add(true);
    await pumpEventQueue();
    expect(realtime.batches, hasLength(1));
    expect(realtime.batches.single.single, containsPair('acc', 5.0));

    realtime.batchAck = true;
    realtime.connectionCtl.add(true);
    await pumpEventQueue();
    expect(realtime.batches, hasLength(2));
    expect(realtime.batches.last, hasLength(1), reason: 'a failed flush keeps the fixes for the next one');
    expect(realtime.batches.last.single['lat'], next.latitude);
    expect(realtime.sent, isEmpty);

    realtime.connectionCtl.add(true);
    await pumpEventQueue();
    expect(realtime.batches, hasLength(2), reason: 'the buffer is empty after a flush the server took');
  });

  test('GPS lost while Location is on: Fix now restarts the stream and a fresh fix clears the banner', () async {
    await session().goOnline();
    expect(locator.gpsListens, 1);
    locator.currentFixCalls = 0;
    session().restartGps();
    await pumpEventQueue();
    expect(locator.gpsListens, 2, reason: 'the GPS stream is subscribed again');
    expect(locator.currentFixCalls, 1, reason: 'a one-shot fix does not wait for the stream');
    expect(state().gpsLost, isFalse);
    // The restarted stream keeps delivering.
    final next = offsetPoint(_here, 80, 0);
    locator.fixes.add(GpsFix(next, at: DateTime.now()));
    await pumpEventQueue();
    expect(session().vehicle.value?.position, next);
  });

  test('decline and timeout clear the card; a declined trip never comes back, a timed-out one can be re-offered', () async {
    await session().goOnline();
    jobs.offersCtl.add(_offer('t1'));
    await pumpEventQueue();
    session().declineRequest();
    expect(state().incoming, isNull);
    await pumpEventQueue();
    expect(jobs.calls.last, 'decline');
    jobs.offersCtl.add(_offer('t1'));
    await pumpEventQueue();
    expect(state().incoming, isNull, reason: 'declined: never shown again');

    jobs.offersCtl.add(_offer('t2'));
    await pumpEventQueue();
    session().requestTimedOut();
    expect(state().missedRequest, isTrue);
    expect(state().incoming, isNull);
    // Dispatch re-offers a timed-out trip to the same driver when nobody else is around.
    jobs.offersCtl.add(_offer('t2'));
    await pumpEventQueue();
    expect(state().incoming?.id, 't2');
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

  test('the server giving the ride to another driver ends the job with its own notice', () async {
    await session().goOnline();
    jobs.offersCtl.add(_offer('t1'));
    await pumpEventQueue();
    await session().acceptRequest();
    jobs.nudgesCtl.add(const TripNudge(tripId: 't1', kind: 'NOT_MOVING', title: 'Are you on the way?', message: 'Please head to the pickup'));
    await pumpEventQueue();
    expect(state().job, isNotNull);
    expect(state().notice?.message, 'Are you on the way? Please head to the pickup');
    jobs.updatesCtl.add(_update('t1', 'SEARCHING'));
    await pumpEventQueue();
    expect(state().job, isNull);
    expect(state().notice?.message, contains('went to another driver'));
  });

  test('a system cancel (never started) says so', () async {
    await session().goOnline();
    jobs.offersCtl.add(_offer('t1'));
    await pumpEventQueue();
    await session().acceptRequest();
    jobs.updatesCtl.add(_update('t1', 'CANCELLED', extra: {'cancelledBy': 'SYSTEM', 'cancelCode': 'STUCK'}));
    await pumpEventQueue();
    expect(state().notice?.message, "The ride didn't start in time, so it was cancelled");
  });

  test('arriving stores when a no-show cancel is allowed', () async {
    await session().goOnline();
    jobs.offersCtl.add(_offer('t1'));
    await pumpEventQueue();
    await session().acceptRequest();
    await session().arrivedAtPickup();
    expect(state().noShowAt, isNotNull);
    expect(state().noShowAt!.difference(DateTime.now()).inSeconds, greaterThan(200));
  });

  test('after a cancel the job steps refuse instead of carrying on without a job', () async {
    await session().goOnline();
    jobs.offersCtl.add(_offer('t1'));
    await pumpEventQueue();
    await session().acceptRequest();
    jobs.updatesCtl.add(_update('t1', 'CANCELLED'));
    await pumpEventQueue();
    final gone = throwsA(isA<ApiException>().having((e) => e.message, 'message', 'This trip was cancelled'));
    await expectLater(session().arrivedAtPickup(), gone);
    await expectLater(session().startTrip(otp: '1234'), gone);
    await expectLater(session().endRide(), gone);
    await expectLater(session().completeDelivery(otp: '1234'), gone);
    expect(jobs.calls.where((c) => c.startsWith('start') || c.startsWith('complete') || c.startsWith('arrived')), isEmpty);
  });

  testWidgets('the passenger cancelling closes the job screens and returns Home', (tester) async {
    // The overlay plugin's channels answer nothing (no bubble in tests).
    final m = tester.binding.defaultBinaryMessenger;
    m.setMockMethodCallHandler(const MethodChannel('x-slayer/overlay_channel'), (_) async => null);
    m.setMockMessageHandler('x-slayer/overlay_messenger', (_) async => null);
    final router = GoRouter(initialLocation: '/home', routes: [
      GoRoute(path: '/home', builder: (_, _) => const Text('Home screen')),
      GoRoute(path: '/driver/pickup', builder: (_, _) => const Text('Pickup screen')),
    ]);
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: RidoDriverApp(router: router)));
    await tester.runAsync(() async {
      await session().goOnline();
      jobs.offersCtl.add(_offer('t1'));
      await pumpEventQueue();
      await session().acceptRequest();
    });
    // Job screens are pushed over Home, like the app does (the router's path stays /home).
    router.push('/driver/pickup');
    await tester.pumpAndSettle();
    expect(find.text('Pickup screen'), findsOneWidget);

    jobs.updatesCtl.add(_update('t1', 'CANCELLED'));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('Pickup screen'), findsNothing);
    expect(find.text('Home screen'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
  });

  test('the driver cancelling calls the API with the reason', () async {
    await session().goOnline();
    jobs.offersCtl.add(_offer('t1'));
    await pumpEventQueue();
    await session().acceptRequest();
    await session().cancelJob(code: CancelCode.vehicleIssue);
    expect(state().job, isNull);
    expect(jobs.calls.last, 'cancel:VEHICLE_ISSUE');
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

  group('too far from the stop', () {
    Future<void> onJob() async {
      await session().goOnline();
      jobs.offersCtl.add(_offer('t1'));
      await pumpEventQueue();
      await session().acceptRequest();
    }

    test('arrived: sends the GPS fix; TOO_FAR keeps the phase until a reason is given', () async {
      await onJob();
      jobs.tooFar = true;
      await expectLater(
        session().arrivedAtPickup(),
        throwsA(isA<ApiException>()
            .having((e) => e.tooFar?.stop, 'stop', 'pickup')
            .having((e) => e.tooFar?.distanceM, 'distance', 850)
            .having((e) => e.tooFar?.reasons, 'reasons', ['GPS is wrong', 'Passenger moved'])
            .having((e) => e.message, 'message', "You're 850 m from the pickup point")),
      );
      expect(state().phase, JobPhase.toPickup);
      expect(jobs.positions.last, _here);

      await session().arrivedAtPickup(farReason: 'Passenger moved');
      expect(state().phase, JobPhase.atPickup);
      expect(jobs.calls.last, 'arrived:Passenger moved');
    });

    test('end ride: TOO_FAR stays in the ride; with a reason it goes to collect', () async {
      await onJob();
      await session().arrivedAtPickup();
      await session().startTrip(otp: '1234');
      jobs.tooFar = true;
      await expectLater(session().endRide(), throwsA(isA<ApiException>().having((e) => e.tooFar?.stop, 'stop', 'drop')));
      expect(state().phase, JobPhase.toDrop);
      await session().endRide(farReason: 'GPS is wrong');
      expect(state().phase, JobPhase.collect);
      expect(jobs.calls.last, 'complete:GPS is wrong');
    });

    test('delivery: a wrong OTP is reported before the distance', () async {
      await onJob();
      jobs.tooFar = true;
      await expectLater(
        session().completeDelivery(otp: '0000'),
        throwsA(isA<ApiException>().having((e) => e.tooFar, 'tooFar', isNull).having((e) => e.status, 'status', 400)),
      );
      await expectLater(
        session().completeDelivery(otp: '5678'),
        throwsA(isA<ApiException>().having((e) => e.tooFar?.distanceM, 'distance', 1200)),
      );
      await session().completeDelivery(otp: '5678', farReason: 'Receiver asked to meet here');
      expect(state().phase, JobPhase.collect);
    });
  });

  test('opening the app never goes online by itself: a stale online state on the API is turned off', () async {
    SharedPreferences.setMockInitialValues({'rido.accessToken': 'token', 'rido.driverId': 'd1'});
    final api = ApiClient(
      baseUrl: 'http://api.test/v1',
      session: ApiSession(await SharedPreferences.getInstance()),
      client: MockClient((req) async => req.url.path.endsWith('/drivers/me')
          ? http.Response('{"id":"d1","isOnline":true,"status":"APPROVED"}', 200)
          : http.Response('{"total":0,"rides":0,"bars":[],"trips":[]}', 200)),
    );
    final rt = FakeRealtime(api);
    final fakeJobs = FakeJobs(api, rt);
    final c = ProviderContainer(overrides: [
      isLiveApiProvider.overrideWithValue(true),
      apiClientProvider.overrideWithValue(api),
      realtimeProvider.overrideWithValue(rt),
      liveJobsProvider.overrideWithValue(fakeJobs),
      driverLocatorProvider.overrideWithValue(FakeLocator()),
      driverRepositoryProvider.overrideWithValue(ApiDriverRepository(api)),
    ]);
    addTearDown(c.dispose);
    c.listen(driverSessionProvider, (_, _) {});
    await c.read(driverSessionProvider.notifier).attach();
    await pumpEventQueue();
    expect(c.read(driverSessionProvider).online, isFalse);
    expect(fakeJobs.calls, contains('offline'));
    expect(fakeJobs.calls, isNot(contains('online')));
  });

  test('offline, the car shows the real position (last known, then the preview stream) and nothing is uploaded', () async {
    await session().locateHere();
    await pumpEventQueue();
    expect(container.read(locationAccessProvider), LocationAccess.granted);
    expect(locator.asked, 1);
    expect(session().vehicle.value?.position, offsetPoint(_here, 300, 90), reason: 'the last known fix shows at once');
    locator.previewFixes.add(GpsFix(_here, at: DateTime.now()));
    await pumpEventQueue();
    expect(session().vehicle.value?.position, _here, reason: 'the offline preview stream keeps it current');
    expect(state().online, isFalse);
    expect(realtime.sent, isEmpty);
    expect(jobs.calls, isNot(contains('online')));
  });

  test('location not allowed: the banner state is set and no position is made up', () async {
    locator.accessResult = LocationAccess.deniedForever;
    await session().locateHere();
    await pumpEventQueue();
    expect(container.read(locationAccessProvider), LocationAccess.deniedForever);
    expect(session().vehicle.value, isNull, reason: 'no Gandhipuram placeholder in live mode');
  });

  test('approximate location only: the car shows offline, going online asks for the precise location', () async {
    locator.accessResult = LocationAccess.approximate;
    await session().locateHere();
    await pumpEventQueue();
    expect(container.read(locationAccessProvider), LocationAccess.approximate);
    expect(session().vehicle.value, isNotNull, reason: 'approximate is enough for the offline car');
    locator.problem = const LocationProblem('Turn on "Use precise location"', fix: LocationFix.appSettings);
    await expectLater(session().goOnline(), throwsA(isA<LocationProblem>()),
        reason: 'checked even with a recent offline fix');
    expect(state().online, isFalse);
  });

  test('indoors: a recent offline position is enough to go online (no waiting for a fresh GPS fix)', () async {
    await session().locateHere();
    await pumpEventQueue();
    locator.currentFixCalls = 0;
    await session().goOnline();
    expect(state().online, isTrue);
    expect(locator.currentFixCalls, 0);
    expect(jobs.calls, contains('online'));
  });
}
