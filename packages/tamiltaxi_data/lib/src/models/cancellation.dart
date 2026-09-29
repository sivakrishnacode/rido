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

/// Where a driver's cancellation rate stands (API `level`): fine, warned, or paused.
enum CancelRateLevel {
  ok,
  nudge,
  block;

  static CancelRateLevel fromApi(Object? v) => switch (v) {
        'NUDGE' => nudge,
        'BLOCK' => block,
        _ => ok,
      };
}

/// `GET /drivers/me/cancel-rate`: the driver's cancellations held against them ÷ assigned trips over 7 days
/// (restarting after a pause), with the banner text and the pause end.
class DriverCancelRate {
  const DriverCancelRate({
    required this.cancelled,
    required this.assigned,
    required this.rate,
    required this.level,
    this.blockedUntil,
    this.title,
    this.body,
    this.blockAt = 0.5,
    this.blockHours = 24,
  });

  factory DriverCancelRate.fromJson(Map<String, dynamic> j) {
    final message = j['message'] is Map ? (j['message'] as Map).cast<String, dynamic>() : null;
    final until = j['blockedUntil'] is String ? DateTime.tryParse(j['blockedUntil'] as String)?.toLocal() : null;
    return DriverCancelRate(
      cancelled: (j['cancelled'] as num?)?.toInt() ?? 0,
      assigned: (j['assigned'] as num?)?.toInt() ?? 0,
      rate: (j['rate'] as num?)?.toDouble() ?? 0,
      level: CancelRateLevel.fromApi(j['level']),
      blockedUntil: until,
      title: message?['title'] as String?,
      body: message?['body'] as String?,
      blockAt: (j['blockAt'] as num?)?.toDouble() ?? 0.5,
      blockHours: (j['blockHours'] as num?)?.toInt() ?? 24,
    );
  }

  final int cancelled;
  final int assigned;
  final double rate;
  final CancelRateLevel level;

  /// Paused until then (null = not paused).
  final DateTime? blockedUntil;

  /// "You've cancelled 2 of your last 5 rides" and what happens next (null when [level] is ok).
  final String? title;
  final String? body;
  final double blockAt;
  final int blockHours;

  bool isPausedAt(DateTime now) => blockedUntil != null && blockedUntil!.isAfter(now);

  /// Show the warning banner on Home.
  bool get shouldWarn => level != CancelRateLevel.ok && title != null;
}
