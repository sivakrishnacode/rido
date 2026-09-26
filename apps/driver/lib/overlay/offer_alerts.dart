import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Ride-request alerts outside the app: the `ride_requests` notification with a full-screen intent (wakes a
/// locked phone and opens the app on the request) that rings once per request, and the small native bridge in `MainActivity` (bring the app to the front,
/// full-screen-intent permission).
///
/// The API sends each offer as a high-priority FCM notification tagged `trip-<id>`. Android draws it itself
/// when the app is in the background or closed, without a full-screen intent, so [showOfferNotification]
/// re-posts it with the same tag and id 0 (FCM's) to replace it; it runs from the FCM background handler and
/// from the app when an offer arrives over the socket.
abstract final class OfferAlerts {
  static const channelId = 'ride_requests';
  static const _channel = AndroidNotificationChannel(
    channelId,
    'Ride requests',
    description: 'New ride and delivery requests',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );
  static const _native = MethodChannel('rido/driver_app');
  static final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  static bool _ready = false;


  static String tagFor(String tripId) => 'trip-$tripId';

  /// Initialises the plugin in this isolate unless RidoPush already did (it owns the tap callback there).
  static Future<void> ensureReady({bool initialise = true}) async {
    if (_ready) return;
    _ready = true;
    try {
      final android = _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(_channel);
      if (initialise) {
        await _local.initialize(
          settings: const InitializationSettings(android: AndroidInitializationSettings('@drawable/ic_notification')),
        );
      }
    } catch (e) {
      debugPrint('Offer alerts unavailable: $e');
    }
  }

  /// The request notification: heads-up, full-screen on a locked phone, ringing until answered or cancelled,
  /// gone when the offer expires.
  static Future<void> showOfferNotification({
    required String tripId,
    required String title,
    required String body,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    try {
      await _local.show(
        id: 0,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            icon: 'ic_notification',
            importance: Importance.max,
            priority: Priority.max,
            category: AndroidNotificationCategory.call,
            fullScreenIntent: true,
            visibility: NotificationVisibility.public,
            tag: tagFor(tripId),
            timeoutAfter: timeout.inMilliseconds,
            autoCancel: true,
            // One ring per request: re-posting the same trip (the FCM push, then the app) doesn't ring again. (It
            // used to be FLAG_INSISTENT, which rang non-stop, and each re-offer started it again.)
            onlyAlertOnce: true,
          ),
        ),
        payload: jsonEncode({'type': 'offer', 'tripId': tripId, 'channel': channelId}),
      );
    } catch (e) {
      debugPrint('Offer notification failed: $e');
    }
  }

  static Future<void> cancelOfferNotification(String tripId) async {
    try {
      await _local.cancel(id: 0, tag: tagFor(tripId));
    } catch (_) {
      // Already gone.
    }
  }

  /// Brings the app's task to the front (allowed from the background while "Display over other apps" is on).
  static Future<void> bringAppToFront() async {
    try {
      await _native.invokeMethod<void>('bringToFront');
    } catch (e) {
      debugPrint('bringToFront failed: $e');
    }
  }

  /// Android 14+: whether requests may open full screen on a locked phone (always true before 14).
  static Future<bool> canUseFullScreenIntent() async {
    try {
      return await _native.invokeMethod<bool>('canUseFullScreenIntent') ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> openFullScreenIntentSettings() async {
    try {
      await _native.invokeMethod<void>('openFullScreenIntentSettings');
    } catch (_) {}
  }
}

/// FCM background handler (own isolate, app in the background or closed): re-posts ride requests with a
/// full-screen intent. Registered in `main()`.
@pragma('vm:entry-point')
Future<void> driverBackgroundPush(RemoteMessage message) async {
  final data = message.data;
  final tripId = data['tripId'];
  if (data['type'] != 'offer' || tripId is! String || tripId.isEmpty) return;
  await OfferAlerts.ensureReady();
  await OfferAlerts.showOfferNotification(
    tripId: tripId,
    title: message.notification?.title ?? 'New ride request',
    body: message.notification?.body ?? 'Open Rido Driver to accept',
    timeout: Duration(milliseconds: message.ttl != null && message.ttl! > 0 ? message.ttl! * 1000 : 20000),
  );
}
