import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:rido_ui/rido_ui.dart';

import '../features/jobs/widgets/request_layout.dart';
import 'overlay_protocol.dart';

/// The floating overlay drawn over other apps (its own engine and isolate, started by
/// flutter_overlay_window at `overlayMain`). It only draws and forwards taps; the app (main isolate) makes
/// every API call and decides what to show ([OverlayMsg]).
///
/// - Bubble: a 64 dp draggable Rido logo that snaps to the nearest edge; tap → open the app.
/// - Request: the overlay grows to full screen with the request card (fare, pickup → drop, pickup distance /
///   ETA, customer, the server's countdown, Accept / Decline). Decline and timeout shrink it back to the bubble.
class DriverOverlayApp extends StatefulWidget {
  const DriverOverlayApp({super.key});

  @override
  State<DriverOverlayApp> createState() => _DriverOverlayAppState();
}

class _DriverOverlayAppState extends State<DriverOverlayApp> {
  StreamSubscription<dynamic>? _sub;
  OverlayOffer? _offer;
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

  void _send(String action, [String? id]) =>
      FlutterOverlayWindow.shareData({OverlayMsg.action: action, 'id': ?id});

  void _onMessage(dynamic raw) {
    if (raw is! Map) return;
    final w = raw['screenW'];
    final h = raw['screenH'];
    if (w is num && h is num && w > 0 && h > 0) _screen = Size(w.toDouble(), h.toDouble());
    switch (raw[OverlayMsg.cmd]) {
      case OverlayMsg.bubble:
        _collapse();
      case OverlayMsg.offer:
        final offer = OverlayOffer.fromJson(raw['offer']);
        if (offer != null) _expand(offer);
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

  Future<void> _expand(OverlayOffer offer) async {
    _collapseTimer?.cancel();
    if (_offer == null) {
      try {
        _bubblePos = await FlutterOverlayWindow.getOverlayPosition();
      } catch (_) {}
    }
    await FlutterOverlayWindow.resizeOverlay(WindowSize.matchParent, _screen.height.round(), false);
    await FlutterOverlayWindow.moveOverlay(const OverlayPosition(0, 0));
    if (!mounted) return;
    setState(() {
      _offer = offer;
      _accepting = false;
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
          _accepting = false;
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
  void _answer(String action) {
    final offer = _offer;
    if (offer == null || _answered || _accepting) return;
    _send(action, offer.id);
    if (action == OverlayMsg.accept) {
      setState(() => _accepting = true);
      _acceptWatchdog?.cancel();
      _acceptWatchdog = Timer(_acceptTimeout, () async {
        if (!mounted || _offer?.id != offer.id) return;
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
    _answered = true;
    _collapse();
  }

  /// The ✕ on the card: back to the bubble and into the app, where the request is still shown until it expires.
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
          : _RequestCard(
              key: ValueKey(offer.id),
              offer: offer,
              accepting: _accepting,
              error: _error,
              onAccept: () => _answer(OverlayMsg.accept),
              onDecline: () => _answer(OverlayMsg.decline),
              onTimeout: () => _answer(OverlayMsg.timeout),
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

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    super.key,
    required this.offer,
    required this.accepting,
    required this.error,
    required this.onAccept,
    required this.onDecline,
    required this.onTimeout,
    required this.onClose,
  });

  final OverlayOffer offer;
  final bool accepting;
  final String? error;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onTimeout;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final left = offer.remaining(DateTime.now());
    return Stack(children: [
      RequestTakeover(
        title: 'New ${offer.isDelivery ? 'delivery' : 'ride'} request',
        tag: RequestVehicleTag(vehicle: offer.vehicle, showIcon: !offer.isDelivery),
        fare: offer.fare,
        fareCaption: '${offer.vehicleLabel} ${offer.isDelivery ? 'delivery' : 'ride'}',
        countdown: left < const Duration(seconds: 1) ? const Duration(seconds: 1) : left,
        running: !accepting && error == null,
        onTimeout: onTimeout,
        below: Text('Cash / UPI to you · 100% yours',
            textAlign: TextAlign.center, style: t.body.copyWith(color: Colors.white)),
        details: [
          PickupDropConnector(
            pickupTitle: offer.pickupName,
            pickupSubtitle: '${formatKm(offer.pickupKm)} away · ${offer.pickupEtaMin} min',
            pickupSubtitleColor: RidoColors.success,
            dropTitle: offer.dropName,
            dropSubtitle: '${formatKm(offer.tripKm)} trip · ~${offer.tripMin} min',
          ),
          const SizedBox(height: RidoSpacing.xl),
          RequestCustomerCard(name: offer.customerName.isEmpty ? 'Rido customer' : offer.customerName, rating: 4.8),
        ],
        onAccept: onAccept,
        onDecline: onDecline,
        accepting: accepting,
      ),
      // Always a way out, whatever state the request is in.
      Positioned(
        top: MediaQuery.paddingOf(context).top + RidoSpacing.s,
        right: RidoSpacing.s,
        child: Semantics(
          button: true,
          label: 'Close and open Rido',
          child: IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
            style: IconButton.styleFrom(backgroundColor: Colors.black26, minimumSize: const Size.square(48)),
          ),
        ),
      ),
      if (error != null)
        Positioned(
          left: RidoSpacing.gutter,
          right: RidoSpacing.gutter,
          bottom: 160,
          child: RidoBanner(type: RidoBannerType.error, title: error!),
        ),
    ]);
  }
}
