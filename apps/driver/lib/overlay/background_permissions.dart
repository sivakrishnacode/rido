import 'package:flutter/widgets.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:rido_ui/rido_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'offer_alerts.dart';

/// The first time the driver goes online (live API): explains and asks for "Display over other apps" (the
/// floating bubble and full-screen requests over other apps) and, on Android 14+, "Full-screen notifications"
/// (requests on a locked phone). Each is asked once; the app keeps working without them (requests then
/// arrive as a normal notification).
Future<void> explainBackgroundPermissions(BuildContext context) async {
  final SharedPreferences prefs;
  try {
    prefs = await SharedPreferences.getInstance();
  } catch (_) {
    return;
  }
  const overlayKey = 'rido.driver.askedOverlay';
  const fullScreenKey = 'rido.driver.askedFullScreenIntent';

  if (!(prefs.getBool(overlayKey) ?? false) && !await _overlayGranted()) {
    await prefs.setBool(overlayKey, true);
    if (!context.mounted) return;
    final ok = await showRidoConfirm(
      context,
      title: 'Get requests over other apps',
      message: 'While you are online, Rido shows a small bubble over other apps (maps, music, WhatsApp) and '
          'pops up new ride requests full screen so you can accept in time.\n\n'
          'On the next screen, find Rido Driver and turn on "Display over other apps".',
      confirmLabel: 'Allow',
      cancelLabel: 'Not now',
      icon: Symbols.picture_in_picture_alt_rounded,
    );
    if (ok) {
      try {
        await FlutterOverlayWindow.requestPermission();
      } catch (_) {}
    }
  }

  if (!(prefs.getBool(fullScreenKey) ?? false) && !await OfferAlerts.canUseFullScreenIntent()) {
    await prefs.setBool(fullScreenKey, true);
    if (!context.mounted) return;
    final ok = await showRidoConfirm(
      context,
      title: 'Show requests on the lock screen',
      message: 'Allow full-screen notifications so a new request lights up the screen even when the phone is '
          'locked or Rido is closed.',
      confirmLabel: 'Open settings',
      cancelLabel: 'Not now',
      icon: Symbols.notifications_active_rounded,
    );
    if (ok) await OfferAlerts.openFullScreenIntentSettings();
  }
}

Future<bool> _overlayGranted() async {
  try {
    return await FlutterOverlayWindow.isPermissionGranted();
  } catch (_) {
    return true; // Not supported here: nothing to ask.
  }
}
