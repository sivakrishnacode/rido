import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rido_data/rido_data.dart';

import '../common/trip_routes.dart';
import 'parcel_flow.dart';
import 'passenger_session.dart';
import 'ride_flow.dart';

/// Live API: reopens the passenger's unfinished ride or parcel after a restart / sign-in.
/// Returns the screen that shows it, or null when there is none (or in mock mode).
Future<String?> restoreActiveTrip(WidgetRef ref) async {
  if (!ref.read(isLiveApiProvider)) return null;
  try {
    final update = await ref.read(liveTripsProvider).active();
    if (update == null) return null;
    if (update.trip.isParcel) {
      ref.read(parcelFlowProvider.notifier).restore(update);
      return routeForParcelPhase(ref.read(parcelFlowProvider).phase);
    }
    ref.read(rideFlowProvider.notifier).restore(update);
    return routeForRidePhase(ref.read(rideFlowProvider).phase);
  } catch (e) {
    debugPrint('No active trip restored: $e');
    return null;
  }
}

/// Signs out and forgets everything tied to the account (flows, profile, lists, the socket).
Future<void> signOut(WidgetRef ref) async {
  try {
    await ref.read(authRepositoryProvider).logout();
  } catch (e) {
    debugPrint('Logout: $e');
  }
  resetSignedInState(ref);
}

/// Drops the signed-in state without calling the API (also used when the token is rejected).
void resetSignedInState(WidgetRef ref) {
  if (ref.read(isLiveApiProvider)) ref.read(realtimeProvider).disconnect();
  ref
    ..invalidate(rideFlowProvider)
    ..invalidate(parcelFlowProvider)
    ..invalidate(passengerProfileProvider)
    ..invalidate(tripHistoryProvider)
    ..invalidate(recentDestinationsProvider)
    ..invalidate(ticketsProvider);
}
