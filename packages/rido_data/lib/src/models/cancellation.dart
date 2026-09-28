/// Who cancelled a trip (API `cancelledBy`).
enum CancelledBy {
  passenger('PASSENGER'),
  driver('DRIVER'),
  system('SYSTEM'),
  admin('ADMIN');

  const CancelledBy(this.api);
  final String api;

  static CancelledBy? fromApi(Object? v) {
    for (final b in values) {
      if (b.api == v) return b;
    }
    return null;
  }
}

/// Why a trip was cancelled (API `cancelCode`, same list as the API's `CancelCode`). [label] is what the cancel
/// sheets show. The API turns a code the sender may not use into [other].
enum CancelCode {
  changedMind('CHANGED_MIND', 'Changed my plan'),
  driverTooFar('DRIVER_TOO_FAR', 'Driver too far'),
  driverAskedToCancel('DRIVER_ASKED_TO_CANCEL', 'Driver asked me to cancel'),
  waitTooLong('WAIT_TOO_LONG', 'Waited too long'),
  bookedByMistake('BOOKED_BY_MISTAKE', 'Booked by mistake'),
  passengerNoShow('PASSENGER_NO_SHOW', "Passenger didn't come"),
  passengerUnreachable('PASSENGER_UNREACHABLE', 'Passenger not reachable'),
  passengerAskedToCancel('PASSENGER_ASKED_TO_CANCEL', 'Passenger asked me to cancel'),
  vehicleIssue('VEHICLE_ISSUE', 'Vehicle problem'),
  tooFar('TOO_FAR', 'Pickup is too far'),
  butterflyMismatch('BUTTERFLY_MISMATCH', 'Rider is not a woman'),
  noDrivers('NO_DRIVERS', 'No drivers available'),
  driverNotMoving('DRIVER_NOT_MOVING', 'Driver was not moving'),
  stuck('STUCK', 'Trip ran far too long'),
  other('OTHER', 'Other reason');

  const CancelCode(this.api, this.label);
  final String api;
  final String label;

  /// S-03 (passenger), in sheet order.
  static const forPassenger = [driverTooFar, changedMind, waitTooLong, driverAskedToCancel, bookedByMistake, other];

  /// D-16 (driver), in sheet order. [passengerNoShow] is offered only once the wait is over; [butterflyMismatch] only on
  /// women-only rides.
  static const forDriver = [passengerUnreachable, passengerAskedToCancel, tooFar, vehicleIssue, other];

  static CancelCode? fromApi(Object? v) {
    for (final c in values) {
      if (c.api == v) return c;
    }
    return null;
  }
}
