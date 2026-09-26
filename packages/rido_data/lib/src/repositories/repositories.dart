import 'package:latlong2/latlong.dart';

import '../models/driver.dart';
import '../models/people.dart';
import '../models/place.dart';
import '../models/trip.dart';
import '../models/vehicle.dart';

/// Thrown by repositories when Demo control "Offline mode" is on (or a real network call fails).
class OfflineException implements Exception {
  const OfflineException();
  @override
  String toString() => "You're offline";
}

/// Thrown when an Autopay / UPI payment fails.
class PaymentFailedException implements Exception {
  const PaymentFailedException(this.amount);
  final int amount;
  @override
  String toString() => 'Your ₹$amount payment didn\'t go through';
}

/// The driver's application is still being reviewed (D-10 "Check status" before an admin has decided).
class StillUnderReviewException implements Exception {
  const StillUnderReviewException();
  @override
  String toString() => 'Your documents are still being reviewed';
}

enum OtpResult { newUser, existingUser, incorrect }

/// Phone + OTP sign-in and the signed-in passenger's profile.
abstract interface class AuthRepository {
  bool get hasSeenOnboarding;
  bool get isLoggedIn;
  void markOnboardingSeen();
  Future<void> sendOtp(String phone);
  Future<OtpResult> verifyOtp(String phone, String otp);
  Future<void> logout();

  Future<PassengerProfile> profile();
  Future<PassengerProfile> updateProfile(PassengerProfile profile);
}

/// Search, saved places and reverse geocoding.
abstract interface class PlacesRepository {
  Place get currentLocation;
  Future<List<Place>> search(String query);

  /// Completes a [search] result before it is used as a pickup / drop: Google suggestions
  /// (id `g:…`) only carry a placeholder location until their details are fetched. Seed places
  /// come back unchanged. Throws [OfflineException] if the place can't be resolved.
  Future<Place> resolve(Place place);
  Future<List<Place>> recentDestinations();
  Future<List<SavedPlace>> savedPlaces();
  Future<List<SavedPlace>> saveSavedPlace(SavedPlace place);
  Future<List<SavedPlace>> removeSavedPlace(String id);

  /// Address at [point] (used by "Pin on map" and the device location).
  Future<Place> reverseGeocode(LatLng point);
  bool isInServiceArea(LatLng point);
}

/// Ride vehicles, quotes, and the passenger's trip history (rides and parcels).
abstract interface class RideRepository {
  List<VehicleType> get rideVehicles;
  Future<List<FareQuote>> quotes(Place from, Place to);

  /// Null when Demo control "No drivers nearby" is on.
  Future<DriverProfile?> findDriver(VehicleKind kind);
  Future<List<Trip>> history();
  Future<Trip?> tripById(String id);
  Future<void> addTrip(Trip trip);
  List<ChatMessage> chatSeed();
  List<String> get quickReplies;
}

/// Goods vehicles and parcel quotes.
abstract interface class ParcelRepository {
  List<VehicleType> get goodsVehicles;
  Future<List<FareQuote>> quotes(Place from, Place to);
  Future<List<Trip>> recentParcels();
}

enum EarningsPeriod { today, week, month }

/// The signed-in driver: profile, KYC, earnings and incoming requests.
abstract interface class DriverRepository {
  bool get isLoggedIn;
  Future<void> sendOtp(String phone);

  /// Any 6 digits except 000000. Signs the driver in on success.
  Future<OtpResult> verifyOtp(String phone, String otp);
  Future<void> logout();

  Future<DriverProfile> profile();
  Future<DriverProfile> updateProfile(DriverProfile profile);

  /// Sign-up (D-04 … D-06): creates the driver with a free trial. Throws [ApiException] on invalid details.
  Future<DriverProfile> register(DriverProfile profile, WorkType workType);
  Future<List<KycDocument>> kycDocuments();
  Future<List<KycDocument>> setKycStatus(KycDocType type, KycStatus status, {String? reason});

  /// D-08: uploads a photo / PDF of [type]; the document goes under review.
  Future<List<KycDocument>> uploadKyc(KycDocType type, List<int> bytes, String filename);

  /// True when approved; false when rejected (Demo control "Reject KYC"). Throws [StillUnderReviewException]
  /// while an admin hasn't decided yet.
  Future<bool> checkApplication();
  Future<EarningsSummary> earnings(EarningsPeriod period);
  Future<void> recordCompletedJob(EarningsTrip trip);
  RideRequest nextRequest(WorkType workType);
  Future<EmergencyContact> emergencyContact();
  Future<void> updateEmergencyContact(EmergencyContact contact);
}

/// The driver's monthly plan and UPI Autopay.
abstract interface class SubscriptionRepository {
  Future<SubscriptionPlan> plan();
  Future<List<PaymentRecord>> payments();
  Future<SubscriptionPlan> setStatus(PlanStatus status);
  Future<SubscriptionPlan> setupAutopay(String upiApp);

  /// Pays one month now. Throws [PaymentFailedException] if Demo control "Fail next payment" is on.
  Future<SubscriptionPlan> payNow(String upiApp);
  Future<SubscriptionPlan> pause();
  Future<SubscriptionPlan> resume();
  Future<SubscriptionPlan> cancel();
  Future<SubscriptionPlan> changePlanVehicle(VehicleKind vehicle);
}

/// Help topics and tickets (shared by both apps).
abstract interface class SupportRepository {
  List<String> topics({required bool driver});
  Future<List<SupportTicket>> tickets();
  Future<SupportTicket> raiseTicket({required String topic, required String description, String? tripId});
}
