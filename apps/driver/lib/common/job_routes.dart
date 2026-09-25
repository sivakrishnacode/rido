import 'package:rido_data/rido_data.dart';

import '../router/routes.dart';
import '../state/driver_session.dart';

/// The screen that shows the current job in [phase] (used by the D-14b banner).
String? routeForJob(JobPhase phase, {required bool delivery}) {
  if (delivery) {
    return switch (phase) {
      JobPhase.none => null,
      JobPhase.toPickup || JobPhase.atPickup || JobPhase.toDrop => Routes.delivery,
      JobPhase.atDrop => Routes.deliveryOtp,
      JobPhase.collect => Routes.collectDelivery,
    };
  }
  return switch (phase) {
    JobPhase.none => null,
    JobPhase.toPickup => Routes.pickup,
    JobPhase.atPickup => Routes.rideOtp,
    JobPhase.toDrop => Routes.trip,
    JobPhase.atDrop => Routes.trip,
    JobPhase.collect => Routes.collect,
  };
}

/// Route for an incoming request.
String requestRoute(RideRequest r) => r.isDelivery ? Routes.deliveryRequest : Routes.request;
