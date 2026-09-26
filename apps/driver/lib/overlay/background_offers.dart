import 'dart:async';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rido_data/rido_data.dart';

import '../state/driver_session.dart';
import '../state/live_helpers.dart';
import 'offer_alerts.dart';
import 'overlay_protocol.dart';

/// Live API, app in the background: the floating Rido bubble while online, the full-screen request card
/// (overlay) with a ringing notification when an offer arrives, and the full-screen-intent notification when "Display over
/// other apps" is off. Accept / Decline / timeout from the overlay go through the same session calls as the
/// in-app card; the overlay isolate never calls the API.
///
/// Hidden when the app is back in front, the driver goes offline, or signs out (the session goes offline).
class BackgroundOffers {
  BackgroundOffers(this._ref, {required this.onAccepted});

  final WidgetRef _ref;

  /// After an Accept from the overlay: show the job's screen (the app comes to the front next).
  final void Function(RideRequest job) onAccepted;

  StreamSubscription<dynamic>? _messages;
  bool _background = false;
  bool _overlayAllowed = false;
  bool _overlayShown = false;
  String? _offerOnOverlay;
  String? _alertFor;
  String? _lastOffer;
  Future<void> _queue = Future.value();

  static const bubbleDp = 64.0;

  /// Going to the background shows the bubble only after this long (no flash on a quick app switch).
  static const _showAfter = Duration(milliseconds: 600);

  /// Every overlay platform call is bounded, so one that never answers can't freeze the queue.
  static const _callTimeout = Duration(seconds: 3);

  Timer? _backgroundTimer;
  final List<Timer> _rechecks = [];

  void start() {
    _messages = FlutterOverlayWindow.overlayListener.listen(_onOverlayMessage, onError: (Object _) {});
    // A bubble left over from before (the app was restarted while it showed) is closed now the app is in front.
    _sync();
  }

  void dispose() {
    _messages?.cancel();
    _backgroundTimer?.cancel();
    for (final t in _rechecks) {
      t.cancel();
    }
    unawaited(_hideAll());
  }

  /// From `didChangeAppLifecycleState`. `inactive` (notification shade, app switcher) changes nothing.
  void onLifecycle(AppLifecycleState state) {
    switch (state) {
      // `detached` is not "back in front": the screen was destroyed but the app (engine) keeps running in the
      // background, so it counts as background (it used to close the bubble).
      case AppLifecycleState.resumed:
        _backgroundTimer?.cancel();
        _background = false;
        _sync();
        // The window service starts asynchronously: re-check shortly so a bubble that appeared late (after the
        // app came back) is closed.
        for (final t in _rechecks) {
          t.cancel();
        }
        _rechecks
          ..clear()
          ..add(Timer(const Duration(milliseconds: 800), _sync))
          ..add(Timer(const Duration(milliseconds: 2500), _sync));
      case AppLifecycleState.paused || AppLifecycleState.hidden || AppLifecycleState.detached:
        if (_background || (_backgroundTimer?.isActive ?? false)) return;
        _backgroundTimer = Timer(_showAfter, () {
          _background = true;
          _sync(checkPermission: true);
        });
      case AppLifecycleState.inactive:
        return;
    }
  }

  /// From a listener on the session (online, incoming request, job).
  void onSession() => _sync();

  void _sync({bool checkPermission = false}) {
    // One change at a time: showing / closing the overlay window must not interleave.
    _queue = _queue
        .then((_) => _apply(checkPermission).timeout(const Duration(seconds: 10)))
        .catchError((Object e) => debugPrint('Overlay: $e'));
  }

  /// Whether the overlay window is really up (the plugin is the source of truth, not [_overlayShown]).
  Future<bool> _isActive() async {
    try {
      return await FlutterOverlayWindow.isActive().timeout(_callTimeout);
    } catch (_) {
      return _overlayShown;
    }
  }

  Future<void> _closeOverlay() async {
    try {
      await FlutterOverlayWindow.closeOverlay().timeout(_callTimeout);
    } catch (e) {
      debugPrint('Overlay close: $e');
    }
    _overlayShown = false;
    _offerOnOverlay = null;
  }

  Future<void> _apply(bool checkPermission) async {
    if (checkPermission) _overlayAllowed = await FlutterOverlayWindow.isPermissionGranted();
    final s = _ref.read(driverSessionProvider);
    final incoming = s.incoming;
    final surface = backgroundSurfaceFor(
      inBackground: _background,
      online: s.online,
      hasRequest: incoming != null,
      overlayAllowed: _overlayAllowed,
    );

    // The overlay window: shown as the bubble, expanded by the overlay itself for a request.
    final wantOverlay = surface == BackgroundSurface.bubble || surface == BackgroundSurface.requestOverlay;
    final active = await _isActive();
    if (wantOverlay && !active) {
      await _showBubbleWindow();
      if (!_overlayShown) return;
    } else if (!wantOverlay && (active || _overlayShown)) {
      await _closeOverlay();
    } else {
      _overlayShown = active;
    }
    if (surface == BackgroundSurface.requestOverlay && incoming != null) {
      if (_offerOnOverlay != incoming.id) {
        _offerOnOverlay = incoming.id;
        await _sendOffer(incoming, s.incomingExpiresAt);
      }
    } else if (_overlayShown && _offerOnOverlay != null) {
      _offerOnOverlay = null;
      await _send({OverlayMsg.cmd: OverlayMsg.bubble, ..._screen()});
    }

    // The ringing request notification (full screen on a locked phone), for the overlay card too.
    final ringFor = surface == BackgroundSurface.requestOverlay || surface == BackgroundSurface.requestNotification
        ? incoming?.id
        : null;
    if (ringFor == null) {
      // In front (the in-app card shows) or answered: silence the request notification, including the one the
      // FCM background handler posted for the same trip.
      final quiet = incoming?.id ?? _lastOffer;
      _lastOffer = null;
      if (quiet != null && quiet != _alertFor) await OfferAlerts.cancelOfferNotification(quiet);
    } else {
      _lastOffer = ringFor;
    }
    if (ringFor != _alertFor) {
      final previous = _alertFor;
      _alertFor = ringFor;
      if (previous != null) await OfferAlerts.cancelOfferNotification(previous);
      if (ringFor != null && incoming != null) {
        await OfferAlerts.showOfferNotification(
          tripId: incoming.id,
          title: 'New ${incoming.isDelivery ? 'delivery' : 'ride'} request · ₹${incoming.fare}',
          body: '${incoming.pickup.name} → ${incoming.drop.name}',
          timeout: _ref.read(driverSessionProvider.notifier).incomingCountdown,
        );
      }
    }
  }

  Future<void> _showBubbleWindow() async {
    final dpr = PlatformDispatcher.instance.views.first.devicePixelRatio;
    final px = (bubbleDp * dpr).round();
    try {
      await FlutterOverlayWindow.showOverlay(
        width: px,
        height: px,
        alignment: OverlayAlignment.topLeft,
        enableDrag: true,
        positionGravity: PositionGravity.auto,
        overlayTitle: 'Rido bubble is on',
        overlayContent: 'Tap the bubble to return to Rido',
        visibility: NotificationVisibility.visibilitySecret,
      ).timeout(_callTimeout);
    } catch (e) {
      debugPrint('Overlay show: $e');
      return;
    }
    // The service starts asynchronously; wait for the window before talking to it.
    for (var i = 0; i < 20 && !await _isActive(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    _overlayShown = true;
    // Came back to the app while it was starting: don't leave it over the app.
    if (!_background) {
      await _closeOverlay();
      return;
    }
    await _send({OverlayMsg.cmd: OverlayMsg.bubble, ..._screen()});
  }

  Future<void> _sendOffer(RideRequest r, DateTime? expiresAt) => _send({
        OverlayMsg.cmd: OverlayMsg.offer,
        'offer': OverlayOffer.fromRequest(
          r,
          expiresAt ?? DateTime.now().add(_ref.read(driverSessionProvider.notifier).incomingCountdown),
        ).toJson(),
        ..._screen(),
      });

  /// The overlay can't measure the screen from inside its small window, so each command carries it (dp).
  static Map<String, Object> _screen() {
    final display = PlatformDispatcher.instance.views.first.display;
    return {'screenW': display.size.width / display.devicePixelRatio, 'screenH': display.size.height / display.devicePixelRatio};
  }

  Future<void> _send(Map<String, Object?> msg) async {
    try {
      await FlutterOverlayWindow.shareData(msg).timeout(_callTimeout);
    } catch (e) {
      debugPrint('Overlay message failed: $e');
    }
  }

  Future<void> _onOverlayMessage(dynamic raw) async {
    if (raw is! Map) return;
    final session = _ref.read(driverSessionProvider.notifier);
    final incoming = _ref.read(driverSessionProvider).incoming;
    final id = raw['id'];
    switch (raw[OverlayMsg.action]) {
      case OverlayMsg.ready:
        // The overlay (re)started: repeat what it should show.
        if (!_overlayShown) return;
        if (_offerOnOverlay != null && incoming != null && incoming.id == _offerOnOverlay) {
          await _sendOffer(incoming, _ref.read(driverSessionProvider).incomingExpiresAt);
        } else {
          await _send({OverlayMsg.cmd: OverlayMsg.bubble, ..._screen()});
        }
      case OverlayMsg.open:
        // Older overlay builds; the patched plugin opens the app natively on a bubble tap.
        await OfferAlerts.bringAppToFront();
      case OverlayMsg.accept:
        if (incoming == null || incoming.id != id) {
          await _send({OverlayMsg.cmd: OverlayMsg.error, 'message': 'This request is no longer available'});
          return;
        }
        await OfferAlerts.cancelOfferNotification(incoming.id);
        await _send({OverlayMsg.cmd: OverlayMsg.accepting});
        try {
          await session.acceptRequest();
        } on Exception catch (e) {
          await _send({OverlayMsg.cmd: OverlayMsg.error, 'message': userMessage(e)});
          return;
        }
        final job = _ref.read(driverSessionProvider).job;
        if (job != null) onAccepted(job);
        await OfferAlerts.bringAppToFront();
      case OverlayMsg.decline:
        if (incoming != null && incoming.id == id) session.declineRequest();
      case OverlayMsg.timeout:
        if (incoming != null && incoming.id == id) session.requestTimedOut();
    }
  }

  Future<void> _hideAll() async {
    await _closeOverlay();
    final ringing = _alertFor;
    if (ringing != null) await OfferAlerts.cancelOfferNotification(ringing);
  }
}
