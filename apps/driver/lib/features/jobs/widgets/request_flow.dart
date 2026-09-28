import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

import '../../../state/driver_session.dart';
import '../../../state/live_helpers.dart';
import '../../../state/request_voice.dart';
import 'job_common.dart';
import 'request_stack_view.dart';

/// Shared D-15 / D-20 logic: the request in focus follows the session (a declined, timed-out or withdrawn request
/// makes way for the next stacked one without leaving the screen), Accept → [acceptRoute], and the card closes
/// only when nothing is left.
mixin RequestFlow<W extends ConsumerStatefulWidget> on ConsumerState<W> {
  /// Opened on its own from the Design gallery: seed state, no timers.
  bool get showcase;

  /// Shown in the gallery / after the last request closes.
  RideRequest get seed;

  /// Where Accept goes (D-16 / D-21).
  String get acceptRoute;

  late final RequestSpeaker _speaker;
  late RideRequest _last = ref.read(driverSessionProvider).incoming ?? seed;
  late Duration _countdown = ref.read(driverSessionProvider.notifier).incomingCountdown;
  String? _handledId;
  bool accepting = false;
  final Set<String> _announced = {};

  /// The request on screen (the last one while the card closes).
  RideRequest get request => _last;

  /// Seconds left on the focused request's ring.
  Duration get countdown => showcase ? ref.read(simTimingProvider)(SimTimings.requestCountdown) : _countdown;

  bool get running => !showcase && !accepting;

  @override
  void initState() {
    super.initState();
    _speaker = ref.read(requestSpeakerProvider);
    _announce(_last);
  }

  @override
  void dispose() {
    // Accepted, declined or gone before the sentence ended: stop talking.
    _speaker.stop();
    super.dispose();
  }

  void _announce(RideRequest r) {
    if (showcase || !ref.read(isLiveApiProvider) || !_announced.add(r.id)) return;
    HapticFeedback.heavyImpact();
    announceRequest(ref, r);
  }

  /// Call from build: follows the session's request in focus.
  void listenForRequests() {
    if (showcase) return;
    // Each request that joins the list is read out too.
    ref.listen(driverSessionProvider.select((s) => s.queued.map((q) => q.request.id).join(',')), (_, _) {
      for (final q in ref.read(driverSessionProvider).queued) {
        _announce(q.request);
      }
    });
    ref.listen(driverSessionProvider.select((s) => s.incoming?.id), (prev, next) {
      if (!mounted) return;
      final incoming = ref.read(driverSessionProvider).incoming;
      if (next == null || incoming == null) {
        // Closed from elsewhere (went offline, withdrawn, nothing left): leave the card.
        if (_handledId != _last.id || prev != null) _close();
        return;
      }
      if (next == _last.id) return;
      _speaker.stop();
      setState(() {
        _last = incoming;
        _countdown = ref.read(driverSessionProvider.notifier).incomingCountdown;
        _handledId = null;
        accepting = false;
      });
      _announce(incoming);
    });
  }

  bool _closed = false;
  void _close() {
    if (_closed || !mounted) return;
    _closed = true;
    popOrHome(context);
  }

  /// Nothing left in focus after an answer: close; otherwise the listener already moved to the next one.
  void _closeIfEmpty() {
    if (ref.read(driverSessionProvider).incoming == null) _close();
  }

  /// Live API: accepting can fail when the offer went to someone else; the next stacked request (if any) stays.
  Future<void> accept() async {
    if (_handledId == _last.id) return;
    if (showcase) {
      context.push(acceptRoute);
      return;
    }
    _handledId = _last.id;
    setState(() => accepting = true);
    try {
      await ref.read(driverSessionProvider.notifier).acceptRequest();
    } on Exception catch (e) {
      if (!mounted) return;
      showRidoSnack(context, userMessage(e));
      setState(() => accepting = false);
      _closeIfEmpty();
      return;
    }
    if (!mounted) return;
    _closed = true;
    context.pushReplacement(acceptRoute);
  }

  void decline() {
    if (_handledId == _last.id) return;
    _handledId = _last.id;
    if (showcase) {
      _close();
      return;
    }
    ref.read(driverSessionProvider.notifier).declineRequest();
    _closeIfEmpty();
  }

  void timeout() {
    if (_handledId == _last.id || showcase || !mounted) return;
    _handledId = _last.id;
    ref.read(driverSessionProvider.notifier).requestTimedOut();
    _closeIfEmpty();
  }

  /// Accepts [tripId] from the comparison list.
  Future<void> acceptOffer(String tripId) async {
    if (tripId != _last.id) {
      ref.read(driverSessionProvider.notifier).focusQueued(tripId);
      _last = ref.read(driverSessionProvider).incoming ?? _last;
      _handledId = null;
    }
    await accept();
  }

  /// Declines (or lets go of, [timedOut]) [tripId] from the comparison list.
  void declineOffer(String tripId, {bool timedOut = false}) {
    if (tripId == _last.id) {
      timedOut ? timeout() : decline();
      return;
    }
    ref.read(driverSessionProvider.notifier).declineOffer(tripId, timedOut: timedOut);
  }

  /// Two or more open requests: the comparison list (rail of rings + a card each); null with just one.
  Widget? stackView({bool delivery = false}) {
    if (showcase) return null;
    final s = ref.watch(driverSessionProvider);
    final incoming = s.incoming;
    if (incoming == null || s.queued.isEmpty) return null;
    return RequestStackView(
      delivery: delivery,
      entries: [
        (request: incoming, expiresAt: s.incomingExpiresAt ?? DateTime.now().add(countdown)),
        for (final q in s.queued) (request: q.request, expiresAt: q.expiresAt),
      ],
      acceptingId: accepting ? _last.id : null,
      onAccept: acceptOffer,
      onDecline: declineOffer,
      onExpired: (id) => declineOffer(id, timedOut: true),
    );
  }
}
