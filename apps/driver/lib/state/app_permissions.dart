import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart' as perm;

import '../overlay/offer_alerts.dart';

/// Android permissions (besides location, see [LocationAccess]) that ride requests depend on. Home shows a
/// banner for the first missing one until it's allowed; nothing here blocks going online.
enum AppPermission {
  /// Requests with the app in the background or closed, and the "You're online" notification.
  notifications,

  /// "Display over other apps": the floating bubble and requests popping up over other apps.
  overlay,

  /// Android 14+ "Full-screen notifications": requests light up a locked phone.
  fullScreen,
}

/// Reads and asks for the [AppPermission]s (overridable in tests).
class AppPermissionChecker {
  const AppPermissionChecker();

  Future<bool> isGranted(AppPermission p) async {
    try {
      return switch (p) {
        AppPermission.notifications => await perm.Permission.notification.isGranted,
        AppPermission.overlay => await FlutterOverlayWindow.isPermissionGranted(),
        AppPermission.fullScreen => await OfferAlerts.canUseFullScreenIntent(),
      };
    } catch (_) {
      return true; // Not on this platform: nothing to ask.
    }
  }

  /// Asks for [p]: the system prompt while Android still shows it, else the matching settings page.
  Future<void> request(AppPermission p) async {
    try {
      switch (p) {
        case AppPermission.notifications:
          final status = await perm.Permission.notification.request();
          // Refused twice: Android no longer shows the prompt, only the app's settings page can allow it.
          if (status.isPermanentlyDenied) await perm.openAppSettings();
        case AppPermission.overlay:
          await FlutterOverlayWindow.requestPermission();
        case AppPermission.fullScreen:
          await OfferAlerts.openFullScreenIntentSettings();
      }
    } catch (_) {
      // No settings screen on this platform.
    }
  }
}

final appPermissionCheckerProvider = Provider<AppPermissionChecker>((ref) => const AppPermissionChecker());

/// The missing [AppPermission]s, most important first. Refreshed when Home opens and whenever the driver comes
/// back to the app (e.g. from a settings page), so the banner goes away once allowed.
class MissingPermissionsController extends Notifier<List<AppPermission>> {
  @override
  List<AppPermission> build() => const [];

  Future<void> refresh() async {
    final checker = ref.read(appPermissionCheckerProvider);
    final missing = [
      for (final p in AppPermission.values)
        if (!await checker.isGranted(p)) p,
    ];
    if (ref.mounted) state = missing;
  }

  Future<void> fix(AppPermission p) async {
    await ref.read(appPermissionCheckerProvider).request(p);
    await refresh();
  }
}

final missingPermissionsProvider =
    NotifierProvider<MissingPermissionsController, List<AppPermission>>(MissingPermissionsController.new);
