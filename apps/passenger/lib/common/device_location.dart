import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:rido_data/rido_data.dart';

import '../state/ride_flow.dart';

/// Outcome of asking for the phone's location.
enum LocateResult {
  /// Location found inside Coimbatore; the pickup was set to it.
  inArea,

  /// Location found but outside the service area; the demo keeps its Coimbatore pickup.
  outsideArea,

  /// Permission denied (once or forever) or location services are off.
  denied,

  /// Not available (e.g. tests, or no GPS fix in time).
  unavailable,
}

/// The phone's real GPS position (via geolocator), or null until located.
class DeviceLocationController extends Notifier<LatLng?> {
  @override
  LatLng? build() => null;

  /// Asks for permission if needed, reads the position and, when it is inside Coimbatore,
  /// sets the ride pickup to it. Never throws.
  Future<LocateResult> locate({bool askPermission = true}) async {
    try {
      if (ref.read(demoSettingsProvider).locationDenied) return LocateResult.denied;
      if (!await Geolocator.isLocationServiceEnabled()) return LocateResult.denied;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied && askPermission) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return LocateResult.denied;

      // Last known fix is instant; a fresh fix can take long indoors, so fall back to it.
      Position? pos = await Geolocator.getLastKnownPosition();
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 8)),
        );
      } catch (_) {
        if (pos == null) rethrow;
      }
      final point = LatLng(pos.latitude, pos.longitude);
      state = point;
      final places = ref.read(placesRepositoryProvider);
      if (!places.isInServiceArea(point)) return LocateResult.outsideArea;
      final place = await places.reverseGeocode(point);
      ref
          .read(rideFlowProvider.notifier)
          .setPickup(place.copyWith(id: 'current', name: 'Current location', address: place.fullAddress));
      return LocateResult.inArea;
    } catch (e) {
      debugPrint('Location unavailable: $e');
      return LocateResult.unavailable;
    }
  }

  /// Opens the app's system settings (S-05 "Open settings").
  Future<void> openSettings() async {
    try {
      await Geolocator.openAppSettings();
    } catch (_) {}
  }
}

final deviceLocationProvider = NotifierProvider<DeviceLocationController, LatLng?>(DeviceLocationController.new);
