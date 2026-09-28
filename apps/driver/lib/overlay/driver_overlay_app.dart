import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:rido_ui/rido_ui.dart';

import '../features/jobs/widgets/request_stack_view.dart';
import 'overlay_protocol.dart';

/// The floating overlay drawn over other apps (its own engine and isolate, started by
/// flutter_overlay_window at `overlayMain`). It only draws and forwards taps; the app (main isolate) makes
/// every API call and decides what to show ([OverlayMsg]).
///
/// - Bubble: a 64 dp draggable Rido logo that snaps to the nearest edge; tap → open the app.
/// - Request: the overlay grows to full screen with the request cards (the app's list: fare and ₹/km, pickup →
///   drop, the server's countdown, swipe to accept, ✕). The last decline / timeout shrinks it back to the bubble.
class DriverOverlayApp extends StatefulWidget {
  const DriverOverlayApp({super.key});

  @override
  State<DriverOverlayApp> createState() => _DriverOverlayAppState();
}

class _DriverOverlayAppState extends State<DriverOverlayApp> {
  StreamSubscription<dynamic>? _sub;
  OverlayOffer? _offer;

  /// The other open requests (the comparison list when not empty).
  List<OverlayOffer> _others = const [];

  /// The request whose Accept was sent (the list locks the others meanwhile).
  String? _acceptingId;
  bool _accepting = false;
  String? _error;
  DateTime? _errorAt;
  bool _answered = false;
  Size _screen = const Size(390, 844);
  OverlayPosition? _bubblePos;
  Timer? _collapseTimer;

  /// Accept sent but the app hasn't taken over: give up, open the app (it shows the request / job itself).
  Timer? _acceptWatchdog;

  static const _bubble = 64;
  static const _acceptTimeout = Duration(seconds: 12);

  @override
  void initState() {
    super.initState();
    _screen = _displaySize() ?? _screen;
    _sub = FlutterOverlayWindow.overlayListener.listen(_onMessage);
    FlutterOverlayWindow.shareData({OverlayMsg.action: OverlayMsg.ready});
  }

  @override
  void dispose() {
    _sub?.cancel();
    _collapseTimer?.cancel();
    _acceptWatchdog?.cancel();
    super.dispose();
  }

  /// The physical screen in dp, from this engine's display (null when not known yet).
  static Size? _displaySize() {
    try {
      final display = PlatformDispatcher.instance.displays.first;
      final size = display.size / display.devicePixelRatio;
      return size.width >= 200 && size.height >= 300 ? size : null;
    } catch (_) {
      return null;
    }
  }

  void _send(String action, [String? id]) =>
      FlutterOverlayWindow.shareData({OverlayMsg.action: action, 'id': ?id});

  void _onMessage(dynamic raw) {
    if (raw is! Map) return;
    // The overlay's own engine sees the physical display: trust it first. The app's value is only a fallback (a
    // minimised app's detached view reported a 1×1 "screen", which parked the bubble off screen).
    final own = _displaySize();
    final w = raw['screenW'];
    final h = raw['screenH'];
    if (own != null) {
      _screen = own;
    } else if (w is num && h is num && w >= 200 && h >= 300) {
      _screen = Size(w.toDouble(), h.toDouble());
    }
    switch (raw[OverlayMsg.cmd]) {
      case OverlayMsg.bubble:
        _collapse();
      case OverlayMsg.offer:
        final offer = OverlayOffer.fromJson(raw['offer']);
        final others = [
          for (final o in (raw['others'] is List ? raw['others'] as List : const [])) ?OverlayOffer.fromJson(o),
        ];
        if (offer != null) _expand(offer, others);
      case OverlayMsg.accepting:
        if (mounted) setState(() => _accepting = true);
      case OverlayMsg.error:
        _acceptWatchdog?.cancel();
        if (!mounted) return;
        setState(() {
          _accepting = false;
          _error = raw['message'] is String ? raw['message'] as String : 'Something went wrong';
          _errorAt = DateTime.now();
        });
        // Don't wait for the app to say so: the card goes back to the bubble once the error has been read.
        _collapse();
    }
  }

  Future<void> _expand(OverlayOffer offer, List<OverlayOffer> others) async {
    _collapseTimer?.cancel();
    // Already open: only the list changed (a request joined or went).
    if (_offer != null && !_accepting) {
      setState(() {
        if (_offer!.id != offer.id) _answered = false;
        _offer = offer;
        _others = others;
      });
      return;
    }
    if (_offer == null) {
      try {
        _bubblePos = await FlutterOverlayWindow.getOverlayPosition();
      } catch (_) {}
    }
    // Full screen by the platform's "match parent", not a measured height (the overlay engine can't always read the
    // display; a guessed 844 dp left the home screen showing below the card).
    await FlutterOverlayWindow.resizeOverlay(WindowSize.matchParent, WindowSize.matchParent, false);
    await FlutterOverlayWindow.moveOverlay(const OverlayPosition(0, 0));
    if (!mounted) return;
    setState(() {
      _offer = offer;
      _others = others;
      _accepting = false;
      _acceptingId = null;
      _answered = false;
      _error = null;
    });
  }

  /// Back to the bubble; an error stays readable on the card for a moment first.
  void _collapse() {
    _collapseTimer?.cancel();
    _acceptWatchdog?.cancel();
    final errorAt = _errorAt;
    final hold = _offer != null && errorAt != null ? const Duration(milliseconds: 2500) - DateTime.now().difference(errorAt) : Duration.zero;
    _collapseTimer = Timer(hold.isNegative ? Duration.zero : hold, () async {
      if (mounted) {
        setState(() {
          _offer = null;
          _others = const [];
          _accepting = false;
          _acceptingId = null;
          _error = null;
          _errorAt = null;
        });
      }
      await FlutterOverlayWindow.resizeOverlay(_bubble, _bubble, true);
      final pos = _bubblePos ?? OverlayPosition(_screen.width - _bubble - 8, _screen.height * 0.35);
      await FlutterOverlayWindow.moveOverlay(pos);
    });
  }

  /// Accept: wait for the app (it accepts over the API and comes to the front), but never forever. Decline /
  /// timeout: the card closes right away, the app is told in the background.
  void _answer(String action, [String? tripId]) {
    final offer = _offer;
    if (offer == null || _answered || _accepting) return;
    final id = tripId ?? offer.id;
    _send(action, id);
    if (action == OverlayMsg.accept) {
      setState(() {
        _accepting = true;
        _acceptingId = id;
      });
      _acceptWatchdog?.cancel();
      _acceptWatchdog = Timer(_acceptTimeout, () async {
        if (!mounted || _offer == null) return;
        setState(() {
          _accepting = false;
          _error = "Rido didn't respond. Opening the app…";
          _errorAt = DateTime.now();
        });
        await FlutterOverlayWindow.openApp();
        _collapse();
      });
      return;
    }
    // One of several: drop its card and wait for the app's updated list; the last one closes the card.
    final rest = [offer, ..._others].where((o) => o.id != id).toList();
    if (rest.isNotEmpty) {
      setState(() {
        _offer = rest.first;
        _others = rest.sublist(1);
      });
      return;
    }
    _answered = true;
    _collapse();
  }

  /// "Open app": back to the bubble and into the app, where the requests are still shown until they expire.
  Future<void> _close() async {
    _collapse();
    await FlutterOverlayWindow.openApp();
  }

  @override
  Widget build(BuildContext context) {
    final offer = _offer;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      color: Colors.transparent,
      theme: RidoTheme.light(),
      home: offer == null
          ? Material(type: MaterialType.transparency, child: _Bubble(onTap: () => _send(OverlayMsg.open)))
          : _StackCard(
              offers: [offer, ..._others],
              acceptingId: _accepting ? _acceptingId : null,
              error: _error,
              onAccept: (id) => _answer(OverlayMsg.accept, id),
              onDecline: (id) => _answer(OverlayMsg.decline, id),
              onTimeout: (id) => _answer(OverlayMsg.timeout, id),
              onClose: _close,
            ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Center(
        child: GestureDetector(
          onTap: onTap,
          child: Semantics(
            button: true,
            label: 'Open Rido Driver',
            child: SizedBox.square(
              dimension: 60,
              child: Stack(children: [
                Container(
                  decoration: const BoxDecoration(shape: BoxShape.circle, boxShadow: RidoShadows.soft),
                  child: ClipOval(child: Image.asset('assets/brand/rido_icon.png', width: 60, height: 60, fit: BoxFit.cover)),
                ),
                // Online dot.
                Positioned(
                  right: 2,
                  bottom: 2,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: RidoColors.success,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2.5),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ),
      );
}

/// The request card(s) over other apps: the same list as in the app.
class _StackCard extends StatelessWidget {
  const _StackCard({
    required this.offers,
    required this.acceptingId,
    required this.error,
    required this.onAccept,
    required this.onDecline,
    required this.onTimeout,
    required this.onClose,
  });

  final List<OverlayOffer> offers;
  final String? acceptingId;
  final String? error;
  final ValueChanged<String> onAccept;
  final ValueChanged<String> onDecline;
  final ValueChanged<String> onTimeout;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Stack(children: [
        RequestStackView(
          entries: [for (final o in offers) (request: o.toRequest(), expiresAt: o.expiresAt)],
          delivery: offers.first.isDelivery,
          acceptingId: acceptingId,
          showVoiceToggle: false,
          // Not a ✕: the card's ✕ declines; this only switches to the app (the requests stay open there).
          topRight: TextButton.icon(
            onPressed: onClose,
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: const Text('Open app'),
            style: TextButton.styleFrom(
              foregroundColor: RidoColors.navy900,
              backgroundColor: RidoColors.inputBg,
              shape: const StadiumBorder(),
              minimumSize: const Size(48, 44),
            ),
          ),
          onAccept: onAccept,
          onDecline: onDecline,
          onExpired: onTimeout,
        ),
        if (error != null)
          Positioned(
            left: RidoSpacing.gutter,
            right: RidoSpacing.gutter,
            bottom: 40,
            child: RidoBanner(type: RidoBannerType.error, title: error!),
          ),
      ]);
}
