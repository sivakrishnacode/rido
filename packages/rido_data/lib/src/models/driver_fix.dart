import 'dart:collection';

import 'package:latlong2/latlong.dart';

/// A driver GPS fix as uploaded to the API (`driver:location`, `driver:locations`, `POST /drivers/me/location(s)`).
class DriverFix {
  const DriverFix(this.point, {required this.at, this.accuracy, this.speed, this.heading, this.isMocked = false});

  final LatLng point;

  /// When the phone took the fix.
  final DateTime at;

  /// Horizontal accuracy in metres, when known.
  final double? accuracy;

  /// Speed in m/s, when known.
  final double? speed;

  /// Direction of travel in degrees, when known.
  final double? heading;

  /// The phone reported a mock (fake-GPS app) location.
  final bool isMocked;

  /// `{lat, lng, ts, acc?, spd?, hdg?, mock}`: [ts] is epoch ms; unknown or invalid extras are left out.
  Map<String, Object> toJson() {
    final acc = accuracy;
    final spd = speed;
    final hdg = heading;
    return {
      'lat': point.latitude,
      'lng': point.longitude,
      'ts': at.millisecondsSinceEpoch,
      if (acc != null && acc.isFinite && acc >= 0) 'acc': double.parse(acc.toStringAsFixed(1)),
      if (spd != null && spd.isFinite && spd >= 0) 'spd': double.parse(spd.toStringAsFixed(2)),
      if (hdg != null && hdg.isFinite && hdg >= 0 && hdg <= 360) 'hdg': double.parse(hdg.toStringAsFixed(1)),
      'mock': isMocked,
    };
  }
}

/// Fixes kept on the phone while the socket is down, oldest first. At [capacity] the oldest fix is dropped, so a
/// long outage keeps the most recent part of the trip.
class FixBuffer {
  FixBuffer({this.capacity = 500});

  final int capacity;
  final Queue<DriverFix> _fixes = Queue();

  int get length => _fixes.length;
  bool get isEmpty => _fixes.isEmpty;

  void add(DriverFix fix) {
    _fixes.addLast(fix);
    while (_fixes.length > capacity) {
      _fixes.removeFirst();
    }
  }

  /// Takes every buffered fix (oldest first) and empties the buffer. Give them back with [restore] if the upload
  /// fails.
  List<DriverFix> drain() {
    final all = _fixes.toList();
    _fixes.clear();
    return all;
  }

  /// Puts [fixes] from a failed upload back in front of any taken since (still capped, oldest dropped first).
  void restore(List<DriverFix> fixes) {
    final newer = _fixes.toList();
    _fixes
      ..clear()
      ..addAll(fixes);
    newer.forEach(add);
    while (_fixes.length > capacity) {
      _fixes.removeFirst();
    }
  }

  void clear() => _fixes.clear();
}
