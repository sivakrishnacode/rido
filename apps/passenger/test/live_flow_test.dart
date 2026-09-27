// The ride and parcel controllers in live API mode, against a fake LiveTrips (no network):
// book → server statuses → phases, driver GPS → ETA, driver cancels (S-02), stale updates, chat,
// passenger cancel vs server cancel, and rating.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_passenger/router/routes.dart';
import 'package:rido_passenger/state/app_notice.dart';
import 'package:rido_passenger/state/parcel_flow.dart';
import 'package:rido_passenger/state/passenger_session.dart';
import 'package:rido_passenger/state/ride_flow.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _driver = DriverProfile(
  id: 'drv-1',
  name: 'Arun Kumar',
  phone: '+919000000001',
  vehicleKind: VehicleKind.bike,
  vehicleModel: 'TVS Jupiter',
  vehicleColor: 'Blue',
  plate: 'TN 37 CD 9876',
  rating: 4.7,
  rides: 120,
  upiId: 'arun@upi',
);

const _quote = FareQuote(
  vehicle: Seed.bike,
  distanceKm: 6.1,
  durationMin: 20,
  base: 12,
  distanceCharge: 30,
  timeCharge: 3,
  subtotal: 45,
  multiplier: 1.1,
  peakCharge: 4,
  total: 49,
);

/// Socket that is always "connected" (so the fallback poll never runs) and never pushes by itself.
class _FakeRealtime extends RealtimeClient {
  _FakeRealtime(super.api);
  @override
  Stream<bool> get connection => const Stream.empty();
  @override
  bool get isConnected => true;
  @override
  void connect() {}
  @override
  Future<bool> joinTrip(String tripId) async => true;
}

/// Records calls; the test pushes server events through [push], [locate] and [message].
class _FakeTrips extends LiveTrips {
  _FakeTrips(super.api, super.realtime);

  final _updates = StreamController<LiveTripUpdate>.broadcast();
  final _locations = StreamController<LiveLocation>.broadcast();
  final _messages = StreamController<ChatMessage>.broadcast();
  final calls = <String>[];
  TripKind kind = TripKind.ride;
  late LiveTripUpdate last;

  LiveTripUpdate update(
    String status, {
    DriverProfile? driver,
    String? cancelReason,
    VehicleKind? vehicle,
    FareQuote quote = _quote,
    List<String> also = const [],
  }) {
    final trip = Trip(
      id: 'trip-1',
      kind: kind,
      vehicle: vehicle ?? (kind == TripKind.parcel ? VehicleKind.threeWheeler : VehicleKind.bike),
      pickup: Seed.gandhipuram,
      drop: Seed.brookefields,
      fare: quote.total,
      quote: quote,
      status: TripStatus.searching,
      startedAt: DateTime(2026, 9, 26, 10),
      driver: driver,
      distanceKm: 6.1,
      durationMin: 20,
      otp: '5821',
      parcel: kind == TripKind.parcel ? kEmptyParcelDetails.copyWith(receiverName: 'Meena', deliveryOtp: '5821') : null,
    );
    return last = LiveTripUpdate(trip, status, {
      'id': 'trip-1',
      'status': status,
      'cancelReason': ?cancelReason,
      'alsoKinds': also,
    });
  }

  List<VehicleAlternative> alternativesResult = const [];

  @override
  Future<List<VehicleAlternative>> alternatives(String tripId) async => alternativesResult;

  @override
  Future<LiveTripUpdate> addVehicle(String tripId, VehicleKind vehicle) async {
    calls.add('also:${vehicle.name}');
    return update('SEARCHING', also: [enumToApi(vehicle)]);
  }

  void push(LiveTripUpdate u) => _updates.add(u);
  void locate(LatLng p) => _locations.add(LiveLocation('trip-1', p, DateTime.now()));
  void message(ChatMessage m) => _messages.add(m);

  @override
  Future<LiveTripUpdate> book({
    required TripKind kind,
    required VehicleKind vehicle,
    required Place pickup,
    required Place drop,
    PaymentMode paymentMode = PaymentMode.cash,
    ParcelDetails? parcel,
    WomenDriverPref womenDriver = WomenDriverPref.none,
    OtherRider? rider,
  }) async {
    calls.add('book:${kind.name}:${vehicle.name}${parcel != null ? ':${parcel.receiverName}' : ''}'
        '${womenDriver.isOn ? ':${womenDriver.name}' : ''}${rider != null ? ':for ${rider.name}' : ''}');
    return update('SEARCHING');
  }

  @override
  Stream<LiveTripUpdate> updates(String tripId) => _updates.stream;
  @override
  Stream<LiveLocation> locations(String tripId) => _locations.stream;
  @override
  Stream<ChatMessage> messages(String tripId) => _messages.stream;
  @override
  Future<List<ChatMessage>> chatHistory(String tripId) async => const [];
  @override
  Future<LiveTripUpdate> poll(String tripId) async => last;

  @override
  Future<ChatMessage> sendMessage(String tripId, String text) async {
    calls.add('send:$text');
    return ChatMessage(id: 'srv-${calls.length}', text: text, fromMe: true, sentAt: DateTime.now());
  }

  @override
  Future<LiveTripUpdate> cancel(String tripId, {String? reason}) async {
    calls.add('cancel:$reason');
    final u = update('CANCELLED');
    push(u);
    return u;
  }

  @override
  Future<void> rate(String tripId, int rating) async => calls.add('rate:$rating');
}

Future<void> _settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late ProviderContainer container;
  late _FakeTrips trips;
  late _FakeRealtime realtime;

  setUp(() async {
    RoadRouter.enabled = false;
    SharedPreferences.setMockInitialValues({});
    final api = ApiClient(baseUrl: 'http://localhost:0/v1', session: ApiSession(await SharedPreferences.getInstance()));
    realtime = _FakeRealtime(api);
    trips = _FakeTrips(api, realtime);
    container = ProviderContainer(
      overrides: [
        isLiveApiProvider.overrideWithValue(true),
        realtimeProvider.overrideWithValue(realtime),
        liveTripsProvider.overrideWithValue(trips),
      ],
    );
    addTearDown(container.dispose);
  });

  RideFlowState ride() => container.read(rideFlowProvider);
  RideFlowController flow() => container.read(rideFlowProvider.notifier);

  test('a ride follows the server from booking to rating', () async {
    flow().setDrop(Seed.brookefields);
    expect(await flow().book(), isNull);
    expect(trips.calls, ['book:ride:bike']);
    expect(ride().phase, RidePhase.searching);
    expect(ride().tripId, 'trip-1');
    expect(ride().otp, '5821', reason: 'the OTP comes from the server');
    expect(ride().quote.total, 49, reason: 'the fare is the server quote stored with the trip');

    trips.push(trips.update('DRIVER_ASSIGNED', driver: _driver));
    await _settle();
    expect(ride().phase, RidePhase.assigned);
    expect(ride().driver.name, 'Arun Kumar');

    // First GPS fix ~2 km from the pickup: approach leg built, ETA from the remaining distance at 20 km/h.
    trips.locate(offsetPoint(Seed.gandhipuram.location, 2000, 90));
    await _settle();
    expect(ride().approach, isNotEmpty);
    expect(flow().vehicle.value, isNotNull);
    expect(ride().etaMin, inInclusiveRange(5, 10));

    // Closer → shorter ETA.
    trips.locate(offsetPoint(Seed.gandhipuram.location, 300, 90));
    await _settle();
    expect(ride().etaMin, inInclusiveRange(1, 3));

    trips.push(trips.update('DRIVER_ARRIVED', driver: _driver));
    await _settle();
    expect(ride().phase, RidePhase.arrived);

    // An old poll answer arriving late must not move the ride backwards.
    trips.push(trips.update('DRIVER_ASSIGNED', driver: _driver));
    await _settle();
    expect(ride().phase, RidePhase.arrived);

    trips.push(trips.update('IN_PROGRESS', driver: _driver));
    await _settle();
    expect(ride().phase, RidePhase.inProgress);
    // At the pickup: nearly the whole quoted 20 minutes are left.
    expect(ride().etaMin, inInclusiveRange(17, 20));

    trips.push(trips.update('COMPLETED', driver: _driver));
    await _settle();
    expect(ride().phase, RidePhase.completed);

    await flow().finishRide(rating: 5);
    expect(trips.calls.last, 'rate:5');
    expect(ride().phase, RidePhase.planning);
  });

  test('Butterfly: a woman rider books "women only"; the choice is ignored for anyone else', () async {
    ProviderContainer rider(PassengerProfile p) {
      final c = ProviderContainer(overrides: [
        isLiveApiProvider.overrideWithValue(true),
        realtimeProvider.overrideWithValue(realtime),
        liveTripsProvider.overrideWithValue(trips),
        currentProfileProvider.overrideWithValue(p),
      ]);
      addTearDown(c.dispose);
      return c;
    }

    final woman = rider(Seed.priya).read(rideFlowProvider.notifier);
    woman.setDrop(Seed.brookefields);
    woman.setWomenDriver(WomenDriverPref.only);
    expect(await woman.book(), isNull);
    expect(trips.calls, ['book:ride:bike:only']);

    final other = rider(Seed.priya.copyWith(gender: Gender.male));
    other.read(rideFlowProvider.notifier).setWomenDriver(WomenDriverPref.only);
    expect(other.read(rideFlowProvider.notifier).canUseButterfly, isFalse);
    expect(other.read(rideFlowProvider.notifier).womenDriver, WomenDriverPref.none);
  });

  test('"Who\'s riding?": a father books Butterfly for his daughter; the next ride is for him again', () async {
    final c = ProviderContainer(overrides: [
      isLiveApiProvider.overrideWithValue(true),
      realtimeProvider.overrideWithValue(realtime),
      liveTripsProvider.overrideWithValue(trips),
      currentProfileProvider.overrideWithValue(Seed.priya.copyWith(name: 'Ravi Kumar', gender: Gender.male)),
    ]);
    addTearDown(c.dispose);
    final f = c.read(rideFlowProvider.notifier);
    expect(f.canUseButterfly, isFalse);

    f.setRider(const OtherRider(name: 'Anjali', phone: '9876512345', isWoman: true));
    expect(f.canUseButterfly, isTrue);
    f.setWomenDriver(WomenDriverPref.only);
    f.setDrop(Seed.brookefields);
    expect(await f.book(), isNull);
    expect(trips.calls, ['book:ride:bike:only:for Anjali']);

    // Someone else who is not a woman: no Butterfly.
    f.setRider(const OtherRider(name: 'Arun', phone: '9876512346'));
    expect(f.womenDriver, WomenDriverPref.none);

    trips.push(trips.update('COMPLETED', driver: _driver));
    await _settle();
    await f.finishRide();
    expect(c.read(rideFlowProvider).rider, isNull);
  });

  test('Skip on P-20 sends no rating', () async {
    await flow().book();
    trips.push(trips.update('COMPLETED', driver: _driver));
    await _settle();
    await flow().finishRide();
    expect(trips.calls.where((c) => c.startsWith('rate')), isEmpty);
  });

  test('the driver cancelling after accepting shows S-02 until someone new accepts', () async {
    await flow().book();
    trips.push(trips.update('DRIVER_ASSIGNED', driver: _driver));
    await _settle();
    trips.push(trips.update('SEARCHING'));
    await _settle();
    expect(ride().phase, RidePhase.driverCancelled);
    expect(ride().driverCancelledOnce, isTrue);
    trips.push(trips.update('DRIVER_ASSIGNED', driver: _driver));
    await _settle();
    expect(ride().phase, RidePhase.assigned);
  });

  test('"Book any": a slow search adds Auto and an auto driver takes it at the auto fare', () async {
    const autoQuote = FareQuote(
      vehicle: Seed.auto,
      distanceKm: 6.1,
      durationMin: 20,
      base: 25,
      distanceCharge: 54,
      timeCharge: 6,
      subtotal: 85,
      multiplier: 1.1,
      peakCharge: 8,
      total: 93,
    );
    await flow().book();
    trips.alternativesResult = const [
      VehicleAlternative(vehicle: VehicleKind.auto, quote: autoQuote, driversNearby: 2, nearestKm: 1.4),
    ];
    await flow().loadAlternatives();
    expect(ride().alternatives.single.vehicle, VehicleKind.auto);

    expect(await flow().addVehicle(VehicleKind.auto), isNull);
    expect(trips.calls.last, 'also:auto');
    expect(ride().alsoVehicles, [VehicleKind.auto]);
    expect(ride().alternatives, isEmpty, reason: 'an added vehicle is no longer offered');

    trips.push(trips.update('DRIVER_ASSIGNED', driver: _driver, vehicle: VehicleKind.auto, quote: autoQuote, also: ['AUTO']));
    await _settle();
    expect(ride().phase, RidePhase.assigned);
    expect(ride().vehicle, VehicleKind.auto);
    expect(ride().quote.total, 93, reason: 'the fare of the vehicle that came');
  });

  test('no drivers ends the search', () async {
    await flow().book();
    trips.push(trips.update('NO_DRIVERS'));
    await _settle();
    expect(ride().phase, RidePhase.noDrivers);
    expect(await flow().cancelSearch(), isNull);
    expect(ride().phase, RidePhase.planning);
    expect(trips.calls.where((c) => c.startsWith('cancel')), isEmpty, reason: 'nothing to cancel on the server');
  });

  test('passenger cancel goes to the API and shows no "cancelled" notice', () async {
    await flow().book();
    expect(await flow().cancelRide(reason: 'Changed my plan'), isNull);
    await _settle();
    expect(trips.calls.last, 'cancel:Changed my plan');
    expect(ride().phase, RidePhase.planning);
    expect(container.read(appNoticeProvider), isNull);
  });

  test('a cancel from the server returns Home with a notice', () async {
    await flow().book();
    trips.push(trips.update('DRIVER_ASSIGNED', driver: _driver));
    await _settle();
    trips.push(trips.update('CANCELLED', cancelReason: 'Vehicle breakdown'));
    await _settle();
    expect(ride().phase, RidePhase.planning);
    final notice = container.read(appNoticeProvider);
    expect(notice?.message, 'Arun cancelled the ride (Vehicle breakdown). You can book again.');
    expect(notice?.goTo, Routes.ride);
  });

  test('chat: my message is sent once, the pushed copy does not duplicate it', () async {
    await flow().book();
    flow().sendChat('I am at the gate');
    expect(ride().chat.single.id, startsWith('local-'));
    await _settle();
    expect(trips.calls.last, 'send:I am at the gate');
    expect(ride().chat.single.id, startsWith('srv-'));
    trips.message(ride().chat.single);
    trips.message(ChatMessage(id: 'srv-99', text: 'Coming', fromMe: false, sentAt: DateTime.now()));
    await _settle();
    expect(ride().chat.map((m) => m.text), ['I am at the gate', 'Coming']);
  });

  test('a parcel books with its details and shows the server delivery OTP', () async {
    trips.kind = TripKind.parcel;
    final parcel = container.read(parcelFlowProvider.notifier);
    parcel.updateDetails(kEmptyParcelDetails.copyWith(receiverName: 'Meena', senderName: 'Priya'));
    parcel.setDrop(Seed.raceCourse);
    expect(await parcel.book(), isNull);
    expect(trips.calls.single, 'book:parcel:threeWheeler:Meena');
    expect(container.read(parcelFlowProvider).details.deliveryOtp, '5821');

    for (final (status, phase) in [
      ('DRIVER_ASSIGNED', ParcelPhase.assigned),
      ('DRIVER_ARRIVED', ParcelPhase.atPickup),
      ('PICKED_UP', ParcelPhase.inTransit),
      ('DELIVERED', ParcelPhase.delivered),
    ]) {
      trips.push(trips.update(status, driver: _driver));
      await _settle();
      expect(container.read(parcelFlowProvider).phase, phase, reason: status);
    }

    await parcel.finish();
    expect(trips.calls.where((c) => c.startsWith('rate')), isEmpty);
    expect(container.read(parcelFlowProvider).phase, ParcelPhase.planning);
    expect(container.read(parcelFlowProvider).details.senderName, 'Priya', reason: 'the sender is kept for next time');
  });
}
