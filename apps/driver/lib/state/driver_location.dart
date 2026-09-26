import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:permission_handler/permission_handler.dart' as perm;
import 'package:rido_data/rido_data.dart';

/// Why the driver can't share a location yet. [message] is shown as is.
class LocationProblem implements Exception {
  const LocationProblem(this.message, {this.fix = LocationFix.none});
  final String message;
  final LocationFix fix;

  @override
  String toString() => message;
}

/// What the "Settings" action of a [LocationProblem] opens.
enum LocationFix { none, locationSettings, appSettings }

/// A GPS fix with the direction of travel (degrees, or null when standing still).
@immutable
class GpsFix {
  const GpsFix(this.point, {this.heading, required this.at});
  final LatLng point;
  final double? heading;
  final DateTime at;
}

/// The phone's GPS for the live driver session (geolocator). While online the stream runs as an Android
/// foreground service with an ongoing notification, so fixes keep flowing when the app is in the
/// background during a job. Only "while in use" permission is asked for (no background location).
class DriverLocator {
  const DriverLocator();

  /// Checks the location service and permission (asking once), then returns a fresh fix.
  Future<GpsFix> currentFix() async {
    await ensureReady();
    try {
      final p = await geo.Geolocator.getCurrentPosition(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return _fix(p);
    } on TimeoutException {
      final last = await geo.Geolocator.getLastKnownPosition();
      if (last != null) return _fix(last);
      throw const LocationProblem("Couldn't get your location. Move to an open area and try again.");
    } on geo.LocationServiceDisabledException {
      throw const LocationProblem('Turn on Location to go online', fix: LocationFix.locationSettings);
    }
  }

  /// Throws [LocationProblem] when the service is off or permission is missing.
  Future<void> ensureReady() async {
    if (!await geo.Geolocator.isLocationServiceEnabled()) {
      throw const LocationProblem('Turn on Location to go online', fix: LocationFix.locationSettings);
    }
    var permission = await geo.Geolocator.checkPermission();
    if (permission == geo.LocationPermission.denied) permission = await geo.Geolocator.requestPermission();
    switch (permission) {
      case geo.LocationPermission.denied:
        throw const LocationProblem('Allow location access so riders can find you');
      case geo.LocationPermission.deniedForever:
        throw const LocationProblem('Location access is off for Rido Driver. Allow it in Settings to go online.',
            fix: LocationFix.appSettings);
      case geo.LocationPermission.whileInUse || geo.LocationPermission.always || geo.LocationPermission.unableToDetermine:
        return;
    }
  }

  /// True when GPS can be used without asking the driver anything (used to resume after a restart).
  Future<bool> isReadyWithoutPrompt() async {
    try {
      if (!await geo.Geolocator.isLocationServiceEnabled()) return false;
      final p = await geo.Geolocator.checkPermission();
      return p == geo.LocationPermission.whileInUse || p == geo.LocationPermission.always;
    } catch (_) {
      return false;
    }
  }

  /// Android 13+: the foreground-service notification needs POST_NOTIFICATIONS. Denying it only hides
  /// the notification; location keeps working.
  Future<void> requestNotificationPermission() async {
    try {
      await perm.Permission.notification.request();
    } catch (_) {
      // Not available on this platform.
    }
  }

  /// A fix about every 5 s while online (standing still included, so dispatch knows the driver is alive).
  Stream<GpsFix> positions() => geo.Geolocator.getPositionStream(locationSettings: _streamSettings()).map(_fix);

  Future<void> openSettings(LocationFix fix) async {
    try {
      switch (fix) {
        case LocationFix.locationSettings:
          await geo.Geolocator.openLocationSettings();
        case LocationFix.appSettings:
          await geo.Geolocator.openAppSettings();
        case LocationFix.none:
          break;
      }
    } catch (_) {
      // No settings screen on this platform.
    }
  }

  static geo.LocationSettings _streamSettings() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return geo.AndroidSettings(
        accuracy: geo.LocationAccuracy.high,
        intervalDuration: const Duration(seconds: 5),
        foregroundNotificationConfig: const geo.ForegroundNotificationConfig(
          notificationTitle: "You're online on Rido Driver",
          notificationText: 'Sharing your location for ride requests and live tracking',
          notificationChannelName: 'Online status',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    }
    return const geo.LocationSettings(accuracy: geo.LocationAccuracy.high);
  }

  static GpsFix _fix(geo.Position p) => GpsFix(
        LatLng(p.latitude, p.longitude),
        heading: p.speed > 1 && p.heading >= 0 ? p.heading : null,
        at: p.timestamp,
      );
}

/// The GPS used by the live session (overridable in tests).
final driverLocatorProvider = Provider<DriverLocator>((ref) => const DriverLocator());
