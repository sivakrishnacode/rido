import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../router/routes.dart';
import '../state/parcel_flow.dart';
import '../state/ride_flow.dart';

/// True while the SOS screen is on top. Trip updates must not navigate then: a `go` replaces the whole stack and
/// would close SOS mid-emergency. SOS opens the trip's current screen itself when it closes.
bool isSosOpen(GoRouter router) => router.routerDelegate.currentConfiguration.lastOrNull?.matchedLocation == Routes.sos;

/// Navigation a trip update causes (a phase change, a notice): skipped while SOS is open ([isSosOpen]).
void goForTrip(BuildContext context, String route) {
  final router = GoRouter.of(context);
  if (!isSosOpen(router)) router.go(route);
}

/// The screen that shows a ride in [phase] (used by the Home "Trip in progress" banner).
String? routeForRidePhase(RidePhase phase) => switch (phase) {
      RidePhase.planning => null,
      RidePhase.searching => Routes.findingDriver,
      RidePhase.noDrivers => Routes.noDrivers,
      RidePhase.assigned => Routes.driverAssigned,
      RidePhase.driverCancelled => Routes.driverCancelled,
      RidePhase.arrived => Routes.driverArrived,
      RidePhase.inProgress => Routes.rideInProgress,
      RidePhase.completed => Routes.rideCompleted,
    };

/// The screen that shows a parcel in [phase].
String? routeForParcelPhase(ParcelPhase phase) => switch (phase) {
      ParcelPhase.planning => null,
      ParcelPhase.searching || ParcelPhase.noDrivers => Routes.parcelFinding,
      ParcelPhase.assigned || ParcelPhase.atPickup => Routes.parcelAssigned,
      ParcelPhase.inTransit => Routes.parcelInTransit,
      ParcelPhase.delivered => Routes.parcelDelivered,
    };
