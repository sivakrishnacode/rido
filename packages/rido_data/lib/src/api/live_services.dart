import 'dart:async';

import 'package:latlong2/latlong.dart';

import '../models/driver.dart';
import '../models/place.dart';
import '../models/trip.dart';
import '../models/vehicle.dart';
import 'api_client.dart';
import 'api_mappers.dart';
import 'demand_map.dart';
import 'realtime_client.dart';
import '../simulation/road_router.dart';

Json _map(dynamic body) => (body as Map).cast<String, dynamic>();

/// A trip update from the API: the mapped [trip] plus the raw API [status] (which also has `NO_DRIVERS`).
class LiveTripUpdate {
  const LiveTripUpdate(this.trip, this.status, this.json);
  final Trip trip;

  /// SEARCHING, NO_DRIVERS, DRIVER_ASSIGNED, DRIVER_ARRIVED, IN_PROGRESS, PICKED_UP, COMPLETED, DELIVERED, CANCELLED.
  final String status;
  final Json json;

  bool get isNoDrivers => status == 'NO_DRIVERS';
}

/// Live driver position on the passenger's map.
class LiveLocation {
  const LiveLocation(this.tripId, this.point, this.at);
  final String tripId;
  final LatLng point;
  final DateTime at;
}

/// Passenger side of a real trip: book, follow it (status, driver GPS, chat), cancel and rate.
///
/// Status arrives as `trip.updated` / `trip.no_drivers` on the user's room; driver location and chat on the trip room.
/// [poll] is the fallback when the socket is down.
class LiveTrips {
  LiveTrips(this.api, this.realtime);
  final ApiClient api;
  final RealtimeClient realtime;

  Future<LiveTripUpdate> book({
    required TripKind kind,
    required VehicleKind vehicle,
    required Place pickup,
    required Place drop,
    PaymentMode paymentMode = PaymentMode.cash,
    ParcelDetails? parcel,
  }) async {
    realtime.connect();
    final res = _map(await api.post('/trips', {
      'kind': kind == TripKind.parcel ? 'PARCEL' : 'RIDE',
      'vehicleKind': enumToApi(vehicle),
      'pickup': pointJson(pickup),
      'drop': pointJson(drop),
      'paymentMode': enumToApi(paymentMode),
      if (parcel != null) 'parcel': parcelToJson(parcel),
      if (parcel != null) 'payer': enumToApi(parcel.payer),
    }));
    final update = _update(res);
    unawaited(realtime.joinTrip(update.trip.id));
    return update;
  }

  /// Status changes of [tripId] (`trip.updated`, `trip.no_drivers`).
  Stream<LiveTripUpdate> updates(String tripId) {
    realtime.connect();
    final updated = realtime.on('trip.updated').where((j) => j['id'] == tripId).map(_update);
    final noDrivers = realtime.on('trip.no_drivers').where((j) => j['tripId'] == tripId).asyncMap((_) => poll(tripId));
    return _merge([updated, noDrivers]);
  }

  /// Driver GPS for [tripId] (joins the trip room).
  Stream<LiveLocation> locations(String tripId) {
    unawaited(realtime.joinTrip(tripId));
    return realtime.on('trip.location').where((j) => j['tripId'] == tripId).map((j) => LiveLocation(
          tripId,
          LatLng((j['lat'] as num).toDouble(), (j['lng'] as num).toDouble()),
          DateTime.fromMillisecondsSinceEpoch((j['at'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch),
        ));
  }

  Stream<ChatMessage> messages(String tripId) =>
      realtime.on('trip.message').where((j) => j['tripId'] == tripId).map((j) => chatFromJson(j, iAmDriver: false));

  Future<List<ChatMessage>> chatHistory(String tripId) async =>
      [for (final m in (await api.get('/trips/$tripId/messages') as List)) chatFromJson(_map(m), iAmDriver: false)];

  Future<ChatMessage> sendMessage(String tripId, String text) async =>
      chatFromJson(_map(await api.post('/trips/$tripId/messages', {'text': text})), iAmDriver: false);

  Future<LiveTripUpdate> poll(String tripId) async => _update(_map(await api.get('/trips/$tripId')));

  /// The passenger's unfinished trip (restores the ride after an app restart), or null.
  Future<LiveTripUpdate?> active() async {
    final res = await api.get('/trips/active');
    if (res == null) return null;
    final update = _update(_map(res));
    unawaited(realtime.joinTrip(update.trip.id));
    return update;
  }

  Future<LiveTripUpdate> cancel(String tripId, {String? reason}) async =>
      _update(_map(await api.post('/trips/$tripId/cancel', {'reason': ?reason})));

  Future<void> rate(String tripId, int rating) => api.post('/trips/$tripId/rate', {'rating': rating});

  static LiveTripUpdate _update(Json j) => LiveTripUpdate(tripFromJson(j), apiStatusOf(j), j);
}

/// A request offered to this driver, with how long it stays open.
class LiveOffer {
  const LiveOffer(this.request, this.expiresInSeconds);
  final RideRequest request;
  final int expiresInSeconds;
}

/// Driver side: online / offline, offers (`trip.offer`), the job lifecycle, GPS and chat.
class LiveJobs {
  LiveJobs(this.api, this.realtime);
  final ApiClient api;
  final RealtimeClient realtime;

  /// Throws [ApiException] (403) when not approved or the plan has lapsed; the message says why.
  Future<void> goOnline(LatLng at) async {
    realtime.connect();
    await api.post('/drivers/me/online', {'lat': at.latitude, 'lng': at.longitude});
  }

  Future<void> goOffline() => api.post('/drivers/me/offline');

  Stream<LiveOffer> offers() {
    realtime.connect();
    return realtime.on('trip.offer').map(_offer);
  }

  /// The offer currently open for this driver (missed while the socket was reconnecting), or null.
  Future<LiveOffer?> currentOffer() async {
    final res = await api.get('/trips/offer');
    return res == null ? null : _offer(_map(res));
  }

  /// Status changes of the job (e.g. the passenger cancelled).
  Stream<LiveTripUpdate> updates(String tripId) =>
      realtime.on('trip.updated').where((j) => j['id'] == tripId).map(LiveTrips._update);

  Future<LiveTripUpdate> accept(String tripId) async {
    final update = LiveTrips._update(_map(await api.post('/trips/$tripId/accept')));
    unawaited(realtime.joinTrip(tripId));
    return update;
  }

  Future<void> decline(String tripId) => api.post('/trips/$tripId/decline');

  /// At the pickup. Throws [ApiException] with [ApiException.tooFar] when [at] is outside the allowed radius and
  /// no [farReason] was given; call again with the driver's reason to continue.
  Future<LiveTripUpdate> arrived(String tripId, {LatLng? at, String? farReason}) async =>
      LiveTrips._update(_map(await api.post('/trips/$tripId/arrived', _position(at, farReason))));

  static Json _position(LatLng? at, String? farReason) => {
        if (at != null) 'lat': at.latitude,
        if (at != null) 'lng': at.longitude,
        'farReason': ?farReason,
      };

  /// Ride: [otp] is the passenger's code. Parcel: marks picked up (no OTP).
  Future<LiveTripUpdate> start(String tripId, {String? otp}) async =>
      LiveTrips._update(_map(await api.post('/trips/$tripId/start', {'otp': ?otp})));

  /// Ride: ends the trip. Parcel: [otp] is the receiver's delivery code. Far from the drop without [farReason] →
  /// [ApiException.tooFar] (the OTP is validated first).
  Future<LiveTripUpdate> complete(String tripId, {String? otp, LatLng? at, String? farReason}) async =>
      LiveTrips._update(_map(await api.post('/trips/$tripId/complete', {'otp': ?otp, ..._position(at, farReason)})));

  Future<LiveTripUpdate> cancel(String tripId, {String? reason}) async =>
      LiveTrips._update(_map(await api.post('/trips/$tripId/cancel', {'reason': ?reason})));

  /// The job this driver is on (restores the app after a restart), or null.
  Future<LiveTripUpdate?> active() async {
    final res = await api.get('/trips/active');
    if (res == null) return null;
    final update = LiveTrips._update(_map(res));
    unawaited(realtime.joinTrip(update.trip.id));
    return update;
  }

  /// GPS fix over the socket (no HTTP request per fix).
  void sendLocation(LatLng p) => realtime.sendLocation(p.latitude, p.longitude);

  /// Keeps the dispatch index fresh when the socket is down.
  Future<void> heartbeat(LatLng p) => api.post('/drivers/me/location', {'lat': p.latitude, 'lng': p.longitude});

  Stream<ChatMessage> messages(String tripId) =>
      realtime.on('trip.message').where((j) => j['tripId'] == tripId).map((j) => chatFromJson(j, iAmDriver: true));

  Future<List<ChatMessage>> chatHistory(String tripId) async =>
      [for (final m in (await api.get('/trips/$tripId/messages') as List)) chatFromJson(_map(m), iAmDriver: true)];

  Future<ChatMessage> sendMessage(String tripId, String text) async =>
      chatFromJson(_map(await api.post('/trips/$tripId/messages', {'text': text})), iAmDriver: true);

  /// Demand hotspots (res-7 hexes with busy res-8 hexes inside) and the service-area outline, for the map.
  Future<DemandMap> demandMap() async => DemandMap.fromJson(_map(await api.get('/demand/hotspots')));

  static LiveOffer _offer(Json j) => LiveOffer(rideRequestFromOffer(j), (j['expiresInSeconds'] as num?)?.toInt() ?? 15);
}

/// Merges streams (small local helper; avoids a dependency on package:async).
Stream<T> _merge<T>(List<Stream<T>> streams) {
  late StreamController<T> controller;
  final subs = <StreamSubscription<T>>[];
  controller = StreamController<T>(
    onListen: () {
      for (final s in streams) {
        subs.add(s.listen(controller.add, onError: controller.addError));
      }
    },
    onCancel: () async {
      for (final s in subs) {
        await s.cancel();
      }
    },
  );
  return controller.stream;
}

/// [RoadRouter.backend] over `POST /maps/route`: two-wheeler routing for bike legs, Google only on the server.
/// Returns null when the server only has an estimate (the router then tries OSRM).
BackendRouter backendRouter(ApiClient api) => (from, to, mode) async {
      final res = _map(await api.post('/maps/route', {
        'from': {'lat': from.latitude, 'lng': from.longitude},
        'to': {'lat': to.latitude, 'lng': to.longitude},
        if (mode == RouteTravelMode.twoWheeler) 'vehicleKind': 'BIKE',
      }, true));
      if (res['source'] != 'google') return null;
      return [
        for (final p in (res['points'] as List? ?? const []))
          LatLng(((p as Map)['lat'] as num).toDouble(), (p['lng'] as num).toDouble()),
      ];
    };
