import '../router/routes.dart';
import '../state/parcel_flow.dart';
import '../state/ride_flow.dart';

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
