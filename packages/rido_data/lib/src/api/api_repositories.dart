import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../models/driver.dart';
import '../models/people.dart';
import '../models/place.dart';
import '../models/trip.dart';
import '../models/vehicle.dart';
import '../repositories/repositories.dart';
import '../seed.dart';
import 'api_client.dart';
import 'api_mappers.dart';

List<Json> _list(dynamic body) => [for (final e in (body as List? ?? const [])) (e as Map).cast<String, dynamic>()];
Json _map(dynamic body) => (body as Map).cast<String, dynamic>();

/// Phone + OTP sign-in and the passenger profile (`/auth`, `/me`).
class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository(this.api);
  final ApiClient api;

  @override
  bool get hasSeenOnboarding => api.session.hasSeenOnboarding;
  @override
  bool get isLoggedIn => api.session.isLoggedIn;
  @override
  void markOnboardingSeen() => api.session.markOnboardingSeen();

  @override
  Future<void> sendOtp(String phone) => api.post('/auth/otp', {'phone': apiPhone(phone)});

  @override
  Future<OtpResult> verifyOtp(String phone, String otp) async {
    try {
      final res = _map(await api.post('/auth/verify', {'phone': apiPhone(phone), 'code': otp}));
      await api.session.save(token: res['accessToken'] as String, driverId: res['driverId'] as String?);
      return res['isNewUser'] == true ? OtpResult.newUser : OtpResult.existingUser;
    } on ApiException catch (e) {
      if (e.status == 400 || e.status == 401) return OtpResult.incorrect;
      rethrow;
    }
  }

  @override
  Future<void> logout() => api.session.clear();

  @override
  Future<PassengerProfile> profile() async => passengerFromJson(_map(await api.get('/me')));

  /// Saves the profile fields, then syncs emergency contacts and saved places by difference.
  @override
  Future<PassengerProfile> updateProfile(PassengerProfile profile) async {
    final current = await this.profile();
    await api.patch('/me', {
      'name': profile.name,
      if (profile.email.isNotEmpty) 'email': profile.email,
      'gender': enumToApi(profile.gender),
      'preferWomenDriver': profile.preferWomenDriver,
      'autoShareTrips': profile.autoShareTrips,
    });
    final keepContacts = {for (final c in profile.emergencyContacts) c.id};
    for (final c in current.emergencyContacts.where((c) => !keepContacts.contains(c.id))) {
      await api.delete('/me/emergency-contacts/${c.id}');
    }
    final known = {for (final c in current.emergencyContacts) c.id};
    for (final c in profile.emergencyContacts.where((c) => !known.contains(c.id))) {
      await api.post('/me/emergency-contacts', {'name': c.name, 'relation': c.relation, 'phone': apiPhone(c.phone)});
    }
    return this.profile();
  }
}

/// Search (Google Places through the API, seeded places as fallback), saved places and reverse geocoding.
class ApiPlacesRepository implements PlacesRepository {
  ApiPlacesRepository(this.api);
  final ApiClient api;

  /// Last known device / pin location (set by the apps when the GPS answers).
  Place _current = Seed.gandhipuram;
  String _session = _newSession();
  final Map<String, bool> _serviceArea = {};

  static String _newSession() {
    final r = math.Random.secure();
    return List.generate(32, (_) => r.nextInt(16).toRadixString(16)).join();
  }

  @override
  Place get currentLocation => _current;

  /// Remembers the device location (used as the default pickup).
  set currentLocation(Place place) => _current = place;

  @override
  Future<List<Place>> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return recentDestinations();
    final res = _map(await api.get('/places/autocomplete', query: {'q': q, 'session': _session}));
    return [for (final r in _list(res['results'])) suggestionFromJson(r)];
  }

  @override
  Future<Place> resolve(Place place) async {
    if (!place.id.startsWith(kApiPlacePrefix)) return place;
    final id = place.id.substring(kApiPlacePrefix.length);
    final res = await api.get('/places/details/${Uri.encodeComponent(id)}', query: {'session': _session});
    _session = _newSession(); // Place Details ends the autocomplete session (one billable session).
    if (res == null) throw const OfflineException();
    final resolved = resolvedPlaceFromJson(_map(res));
    return resolved.copyWith(name: place.name.isNotEmpty ? place.name : resolved.name);
  }

  /// Recent drops from the trip history (unique), newest first.
  @override
  Future<List<Place>> recentDestinations() async {
    final trips = _list(await api.get('/trips')).map(tripFromJson);
    final seen = <String>{};
    return [
      for (final t in trips)
        if (seen.add(t.drop.name)) t.drop.copyWith(id: 'recent-${t.id}'),
    ].take(6).toList();
  }

  @override
  Future<List<SavedPlace>> savedPlaces() async {
    final me = _map(await api.get('/me'));
    return [for (final p in _list(me['savedPlaces'])) savedPlaceFromJson(p)];
  }

  /// Adds, or replaces (delete + add) when [place] already has a server id.
  @override
  Future<List<SavedPlace>> saveSavedPlace(SavedPlace place) async {
    final existing = await savedPlaces();
    if (existing.any((p) => p.id == place.id)) await api.delete('/me/saved-places/${place.id}');
    await api.post('/me/saved-places', savedPlaceToJson(place));
    return savedPlaces();
  }

  @override
  Future<List<SavedPlace>> removeSavedPlace(String id) async {
    await api.delete('/me/saved-places/$id');
    return savedPlaces();
  }

  @override
  Future<Place> reverseGeocode(LatLng point) async {
    final res = _map(await api.get('/places/reverse', query: {'lat': point.latitude, 'lng': point.longitude}));
    _serviceArea[_key(point)] = res['isInServiceArea'] == true;
    final place = res['place'];
    // Keep the exact pin: the API may return the nearest known place's name.
    return place == null
        ? Place(id: 'pin-${_key(point)}', name: 'Pinned location', address: '', location: point)
        : resolvedPlaceFromJson(_map(place)).copyWith(id: 'pin-${_key(point)}', location: point);
  }

  /// From the last reverse geocode near [point]; otherwise within 18 km of Coimbatore (the seeded service area).
  /// Booking is checked again by the API.
  @override
  bool isInServiceArea(LatLng point) =>
      _serviceArea[_key(point)] ?? const Distance().as(LengthUnit.Kilometer, point, kCityCentre) <= 18;

  static String _key(LatLng p) => '${p.latitude.toStringAsFixed(4)},${p.longitude.toStringAsFixed(4)}';
}

/// Ride quotes and trip history. Booking and live trips go through [LiveTrips].
class ApiRideRepository implements RideRepository {
  ApiRideRepository(this.api);
  final ApiClient api;

  @override
  List<VehicleType> get rideVehicles => Seed.rideVehicles;

  @override
  Future<List<FareQuote>> quotes(Place from, Place to) => _quotes(api, from, to, 'RIDE');

  /// Not used with the live API: dispatch assigns a driver and pushes `trip.updated`.
  @override
  Future<DriverProfile?> findDriver(VehicleKind kind) async => null;

  @override
  Future<List<Trip>> history() async => _list(await api.get('/trips')).map(tripFromJson).toList();

  @override
  Future<Trip?> tripById(String id) async {
    try {
      return tripFromJson(_map(await api.get('/trips/$id')));
    } on ApiException catch (e) {
      if (e.status == 404) return null;
      rethrow;
    }
  }

  /// The API records trips itself.
  @override
  Future<void> addTrip(Trip trip) async {}

  @override
  List<ChatMessage> chatSeed() => const [];

  @override
  List<String> get quickReplies => Seed.quickReplies;
}

Future<List<FareQuote>> _quotes(ApiClient api, Place from, Place to, String kind) async {
  final res = _map(await api.post('/fares/quote', {'pickup': pointJson(from), 'drop': pointJson(to), 'kind': kind}));
  return [for (final q in _list(res['quotes'])) quoteFromJson(q)];
}

class ApiParcelRepository implements ParcelRepository {
  ApiParcelRepository(this.api);
  final ApiClient api;

  @override
  List<VehicleType> get goodsVehicles => Seed.goodsVehicles;

  @override
  Future<List<FareQuote>> quotes(Place from, Place to) => _quotes(api, from, to, 'PARCEL');

  @override
  Future<List<Trip>> recentParcels() async =>
      _list(await api.get('/trips')).map(tripFromJson).where((t) => t.isParcel).toList();
}

/// The signed-in driver: sign-up, profile, KYC uploads and earnings. Requests and jobs go through [LiveJobs].
class ApiDriverRepository implements DriverRepository {
  ApiDriverRepository(this.api);
  final ApiClient api;

  /// Signed in with a driver account (a phone that hasn't finished sign-up has a token but no driver id).
  @override
  bool get isLoggedIn => api.session.isLoggedIn && (api.session.driverId ?? '').isNotEmpty;

  @override
  Future<void> sendOtp(String phone) => api.post('/auth/otp', {'phone': apiPhone(phone)});

  /// existingUser = already a driver; newUser = continue to sign-up (the token is kept for [register]).
  @override
  Future<OtpResult> verifyOtp(String phone, String otp) async {
    try {
      final res = _map(await api.post('/auth/verify', {'phone': apiPhone(phone), 'code': otp}));
      final driverId = res['driverId'] as String?;
      await api.session.save(token: res['accessToken'] as String, driverId: driverId);
      return driverId == null ? OtpResult.newUser : OtpResult.existingUser;
    } on ApiException catch (e) {
      if (e.status == 400 || e.status == 401) return OtpResult.incorrect;
      rethrow;
    }
  }

  @override
  Future<void> logout() async {
    try {
      if (isLoggedIn) await api.post('/drivers/me/offline');
    } on Exception {
      // Signing out works offline too.
    }
    await api.session.clear();
  }

  @override
  Future<DriverProfile> profile() async => driverFromJson(_map(await api.get('/drivers/me')));

  @override
  Future<DriverProfile> updateProfile(DriverProfile profile) async => driverFromJson(_map(await api.patch('/drivers/me', {
        'name': profile.name,
        'gender': enumToApi(profile.gender),
        'vehicleModel': profile.vehicleModel,
        'vehicleColor': profile.vehicleColor,
        'plate': profile.plate,
        'upiId': profile.upiId,
      })));

  @override
  Future<DriverProfile> register(DriverProfile profile, WorkType workType) async {
    final res = _map(await api.post('/drivers', {
      'name': profile.name,
      'workType': enumToApi(workType),
      'vehicleKind': enumToApi(profile.vehicleKind),
      'vehicleModel': profile.vehicleModel,
      'vehicleColor': profile.vehicleColor,
      'plate': profile.plate,
      'upiId': profile.upiId,
    }));
    final driver = _map(res['driver']);
    await api.session.save(token: res['accessToken'] as String, driverId: driver['id'] as String);
    return this.profile();
  }

  @override
  Future<List<KycDocument>> kycDocuments() async => _list(await api.get('/drivers/me/documents')).map(kycFromJson).toList();

  /// Only an admin changes review status with the live API; this just reloads the list.
  @override
  Future<List<KycDocument>> setKycStatus(KycDocType type, KycStatus status, {String? reason}) => kycDocuments();

  @override
  Future<List<KycDocument>> uploadKyc(KycDocType type, List<int> bytes, String filename) async {
    await api.upload('/drivers/me/documents/${enumToApi(type)}', field: 'file', bytes: bytes, filename: filename);
    return kycDocuments();
  }

  @override
  Future<bool> checkApplication() async {
    final me = _map(await api.get('/drivers/me'));
    return switch (me['status']) {
      'APPROVED' => true,
      'REJECTED' => false,
      _ => throw const StillUnderReviewException(),
    };
  }

  @override
  Future<EarningsSummary> earnings(EarningsPeriod period) async =>
      earningsFromJson(_map(await api.get('/drivers/me/earnings', query: {'period': period.name})));

  /// The API records completed jobs itself.
  @override
  Future<void> recordCompletedJob(EarningsTrip trip) async {}

  /// Not used with the live API: offers arrive as `trip.offer` (see [LiveJobs]).
  @override
  RideRequest nextRequest(WorkType workType) => throw UnsupportedError('Requests come from dispatch');

  @override
  Future<EmergencyContact> emergencyContact() async {
    final me = _map(await api.get('/me'));
    final contacts = _list(me['emergencyContacts']);
    return contacts.isEmpty
        ? const EmergencyContact(id: '', name: '', relation: '', phone: '')
        : contactFromJson(contacts.first);
  }

  /// Drivers keep one contact: replaces the current one.
  @override
  Future<void> updateEmergencyContact(EmergencyContact contact) async {
    final me = _map(await api.get('/me'));
    for (final c in _list(me['emergencyContacts'])) {
      await api.delete('/me/emergency-contacts/${c['id']}');
    }
    await api.post('/me/emergency-contacts', {'name': contact.name, 'relation': contact.relation, 'phone': apiPhone(contact.phone)});
  }
}

/// Plans and (simulated) UPI Autopay (`/plans`, `/subscriptions`).
class ApiSubscriptionRepository implements SubscriptionRepository {
  ApiSubscriptionRepository(this.api);
  final ApiClient api;

  @override
  Future<SubscriptionPlan> plan() async {
    final res = await api.get('/subscriptions/me');
    if (res == null) throw const ApiException(404, 'No plan yet');
    return planFromJson(_map(res));
  }

  @override
  Future<List<PaymentRecord>> payments() async {
    final paid = _list(await api.get('/subscriptions/me/payments')).map(paymentFromJson).toList();
    final current = await api.get('/subscriptions/me');
    if (current is Map && current['status'] == 'TRIAL') {
      final trial = planFromJson(current.cast());
      paid.add(PaymentRecord(label: 'Free trial', amount: 0, status: PaymentRecordStatus.freeTrial, date: trial.startedAt));
    }
    return paid;
  }

  /// Only pause / resume / cancel can be set by the driver; other statuses come from the API.
  @override
  Future<SubscriptionPlan> setStatus(PlanStatus status) => switch (status) {
        PlanStatus.paused => pause(),
        PlanStatus.cancelled => cancel(),
        PlanStatus.active => resume(),
        _ => plan(),
      };

  @override
  Future<SubscriptionPlan> setupAutopay(String upiApp) async =>
      planFromJson(_map(await api.post('/subscriptions/me/autopay', {'upiApp': upiApp})));

  /// Buys the monthly plan for the driver's vehicle (extends from the current end date).
  @override
  Future<SubscriptionPlan> payNow(String upiApp) async {
    final current = await plan();
    final plans = _list(await api.get('/plans', query: {'vehicleKind': enumToApi(current.vehicle)}));
    final monthly = plans.firstWhere((p) => p['period'] == 'MONTHLY', orElse: () => plans.first);
    try {
      return planFromJson(_map(await api.post('/subscriptions', {'planId': monthly['id'], 'upiApp': upiApp})));
    } on ApiException {
      throw PaymentFailedException(_intOf(monthly['price']));
    }
  }

  @override
  Future<SubscriptionPlan> pause() async => planFromJson(_map(await api.post('/subscriptions/me/pause')));
  @override
  Future<SubscriptionPlan> resume() async => planFromJson(_map(await api.post('/subscriptions/me/resume')));
  @override
  Future<SubscriptionPlan> cancel() async => planFromJson(_map(await api.post('/subscriptions/me/cancel')));

  /// Plans are priced per vehicle and the vehicle is fixed at sign-up; support changes it after checking the RC.
  @override
  Future<SubscriptionPlan> changePlanVehicle(VehicleKind vehicle) async =>
      throw const ApiException(400, 'To change your vehicle, raise a "Documents / KYC" ticket in Help');

  static int _intOf(Object? v) => v is num ? v.round() : 0;
}

class ApiSupportRepository implements SupportRepository {
  ApiSupportRepository(this.api);
  final ApiClient api;

  @override
  List<String> topics({required bool driver}) => driver ? Seed.driverHelpTopics : Seed.helpTopics;

  @override
  Future<List<SupportTicket>> tickets() async => _list(await api.get('/tickets')).map(ticketFromJson).toList();

  @override
  Future<SupportTicket> raiseTicket({required String topic, required String description, String? tripId}) async =>
      ticketFromJson(_map(await api.post('/tickets', {'topic': topic, 'description': description, 'tripId': ?tripId})));
}
