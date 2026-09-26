/// Every passenger route path. Build navigation with these, never with string literals.
abstract final class Routes {
  // Start-up and sign-in
  static const splash = '/splash';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const otp = '/login/otp';
  static const profileSetup = '/profile-setup';
  static const locationPermission = '/location-permission';
  static const locationDenied = '/location-denied';
  static const serviceUnavailable = '/service-unavailable';
  static String legal(String doc) => '/legal/$doc';

  // Ride tab
  static const ride = '/ride';
  static const search = '/ride/search';
  static const pinOnMap = '/ride/pin';
  static const pinPickupOnMap = '/ride/pin?for=pickup';
  static const pinPickOnMap = '/ride/pin?for=pick';
  static const chooseVehicle = '/ride/choose-vehicle';
  static const findingDriver = '/ride/finding';
  static const driverAssigned = '/ride/driver';
  static const chat = '/ride/chat';
  static const driverArrived = '/ride/arrived';
  static const rideInProgress = '/ride/trip';
  static const rideCompleted = '/ride/completed';
  static const rateDriver = '/ride/rate';
  static const noDrivers = '/ride/no-drivers';
  static const driverCancelled = '/ride/driver-cancelled';
  static String savedPlaceEditor([String? id]) => id == null ? '/ride/saved-place' : '/ride/saved-place?id=$id';

  // Parcel tab
  static const parcel = '/parcel';
  static const parcelPickup = '/parcel/pickup';
  static const parcelDrop = '/parcel/drop';
  static const parcelDetails = '/parcel/details';
  static const parcelReview = '/parcel/review';
  static const parcelFinding = '/parcel/finding';
  static const parcelAssigned = '/parcel/assigned';
  static const parcelChat = '/parcel/chat';
  static const parcelInTransit = '/parcel/in-transit';
  static const parcelDelivered = '/parcel/delivered';

  // Activity tab
  static const activity = '/activity';
  static String tripDetails(String id) => '/activity/trip/$id';

  // Account tab
  static const account = '/account';
  static const editProfile = '/account/edit-profile';
  static const savedPlaces = '/account/saved-places';
  static const safety = '/account/safety';
  static const about = '/account/about';
  static const contribute = '/account/contribute';
  static const emergencyContacts = '/account/emergency-contacts';

  // Full-screen, reachable from anywhere
  static const sos = '/sos';
  static String help({String? tripId}) => tripId == null ? '/help' : '/help?trip=$tripId';
  static String newTicket({String? topic, String? tripId}) {
    final q = [if (topic != null) 'topic=${Uri.encodeComponent(topic)}', if (tripId != null) 'trip=$tripId'];
    return q.isEmpty ? '/help/new-ticket' : '/help/new-ticket?${q.join('&')}';
  }

  static const gallery = '/gallery';
  static String galleryView(String frameId) => '/gallery/view/$frameId';
}
