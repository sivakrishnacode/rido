import 'dart:math' as math;

import 'package:latlong2/latlong.dart' show Distance, LengthUnit;
import 'package:rido_data/rido_data.dart';

import 'driver_session.dart';

/// Pure helpers for the live (API) driver session. Kept free of Flutter and Riverpod so they
/// can be unit-tested.

/// Where the job screens are for a trip in API [status] (`DRIVER_ASSIGNED`, `PICKED_UP`, …).
/// "Reached drop" for deliveries is a local step, so a restored parcel in transit is [JobPhase.toDrop].
JobPhase jobPhaseForStatus(String status) => switch (status) {
      'DRIVER_ASSIGNED' => JobPhase.toPickup,
      'DRIVER_ARRIVED' => JobPhase.atPickup,
      'IN_PROGRESS' || 'PICKED_UP' => JobPhase.toDrop,
      'COMPLETED' || 'DELIVERED' => JobPhase.collect,
      _ => JobPhase.none,
    };

/// GPS upload rule while online: send when at least [minGap] passed since the last upload, or the
/// driver moved [minMetres] (but never more often than every [floor]).
bool shouldSendFix({
  required LatLng? last,
  required DateTime? lastAt,
  required LatLng next,
  required DateTime now,
  Duration minGap = const Duration(seconds: 5),
  double minMetres = 20,
  Duration floor = const Duration(seconds: 2),
}) {
  if (last == null || lastAt == null) return true;
  final gap = now.difference(lastAt);
  if (gap >= minGap) return true;
  if (gap < floor) return false;
  return const Distance().as(LengthUnit.Meter, last, next) >= minMetres;
}

double _km(LatLng a, LatLng b) => const Distance().as(LengthUnit.Meter, a, b) / 1000;

/// Length of [route] in km.
double routeKm(List<LatLng> route) {
  var total = 0.0;
  for (var i = 1; i < route.length; i++) {
    total += _km(route[i - 1], route[i]);
  }
  return total;
}

/// Share of [route] still ahead of [pos] (0 = at the end, 1 = at the start), measured from the
/// route vertex closest to [pos]. No routing calls: ETA comes from progress along the stored polyline.
double remainingFraction(List<LatLng> route, LatLng pos) {
  if (route.length < 2) return 0;
  var nearest = 0;
  var best = double.infinity;
  for (var i = 0; i < route.length; i++) {
    final d = _km(route[i], pos);
    if (d < best) {
      best = d;
      nearest = i;
    }
  }
  final total = routeKm(route);
  if (total <= 0) return 0;
  final ahead = best + routeKm(route.sublist(nearest));
  return (ahead / total).clamp(0.0, 1.0);
}

/// Minutes left on a [totalMin] leg for a driver at [pos].
int etaAlong(List<LatLng> route, LatLng pos, int totalMin) {
  if (totalMin <= 0) return 0;
  return (totalMin * remainingFraction(route, pos)).ceil();
}

/// City-speed estimate (~20 km/h) for a leg the API gave no duration for.
int estimateMinutes(double km) => math.max(1, (km * 3).ceil());

/// A job from the API (accept result, `GET /trips/active`) for the job screens. [offer] keeps what
/// only the offer had (pickup distance / ETA, the passenger's phone).
RideRequest rideRequestFromUpdate(LiveTripUpdate update, {RideRequest? offer}) {
  final trip = update.trip;
  final passenger = update.json['passenger'];
  final p = passenger is Map ? passenger : const {};
  final name = p['name'] is String && (p['name'] as String).isNotEmpty ? p['name'] as String : null;
  final phone = p['phone'] is String && (p['phone'] as String).isNotEmpty ? p['phone'] as String : null;
  return RideRequest(
    id: trip.id,
    kind: trip.kind,
    vehicle: trip.vehicle,
    fare: trip.fare > 0 ? trip.fare : (offer?.fare ?? 0),
    pickup: trip.pickup,
    drop: trip.drop,
    pickupDistanceKm: offer?.pickupDistanceKm ?? 0,
    pickupEtaMin: offer?.pickupEtaMin ?? 0,
    tripKm: trip.distanceKm > 0 ? trip.distanceKm : (offer?.tripKm ?? 0),
    tripMin: trip.durationMin > 0 ? trip.durationMin : (offer?.tripMin ?? 0),
    customerName: name ?? offer?.customerName ?? 'Rido customer',
    customerRating: offer?.customerRating ?? 4.8,
    customerPhone: phone ?? offer?.customerPhone ?? '',
    parcel: trip.parcel ?? offer?.parcel,
    // The driver never sees the ride OTP: the passenger reads it out and the API checks it.
    otp: '',
  );
}

/// A message for a snack bar from anything a repository or the session throws.
String userMessage(Object error) {
  if (error is ApiException) return error.message;
  if (error is OfflineException) return "You're offline. Check your connection and try again.";
  final text = error.toString();
  return text.startsWith('Exception') || text.startsWith('Instance of') ? 'Something went wrong. Please try again.' : text;
}

/// Number plate rule of the API (`TN 37 AB 4521`).
final RegExp kPlatePattern = RegExp(r'^[A-Z]{2}\s?\d{1,2}\s?[A-Z]{0,3}\s?\d{1,4}$', caseSensitive: false);

/// UPI ID rule of the API (`name@bank`).
final RegExp kUpiPattern = RegExp(r'^[\w.-]{2,}@[a-z]{2,}$', caseSensitive: false);
