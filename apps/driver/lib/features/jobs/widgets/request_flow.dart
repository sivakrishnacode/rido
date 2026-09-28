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

  /// The other open requests as chips (tap one to look at it), or nothing.
  Widget stackChips() {
    if (showcase) return const SizedBox.shrink();
    final queued = ref.watch(driverSessionProvider.select((s) => s.queued));
    return RequestStackChips(
      queued: queued,
      onFocus: (id) => ref.read(driverSessionProvider.notifier).focusQueued(id),
    );
  }
}

/// "+2 more": the other open requests, each with its fare, pickup distance and a shrinking ring; tap to switch.
class RequestStackChips extends StatelessWidget {
  const RequestStackChips({super.key, required this.queued, required this.onFocus});
  final List<QueuedOffer> queued;
  final ValueChanged<String> onFocus;

  @override
  Widget build(BuildContext context) {
    if (queued.isEmpty) return const SizedBox.shrink();
    final t = context.type;
    return Padding(
      padding: const EdgeInsets.only(top: RidoSpacing.m),
      child: SizedBox(
        height: 52,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            Center(
              child: Text('+${queued.length} more', style: t.bodySmallMedium.copyWith(color: Colors.white)),
            ),
            for (final q in queued)
              Padding(
                padding: const EdgeInsets.only(left: RidoSpacing.s),
                child: _StackChip(offer: q, onTap: () => onFocus(q.request.id)),
              ),
          ],
        ),
      ),
    );
  }
}

class _StackChip extends StatelessWidget {
  const _StackChip({required this.offer, required this.onTap});
  final QueuedOffer offer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final r = offer.request;
    final left = offer.expiresAt.difference(DateTime.now());
    return Semantics(
      button: true,
      label: 'Another request, ${formatInr(r.fare)}, pickup ${formatKm(r.pickupDistanceKm)} away. Tap to see it',
      excludeSemantics: true,
      child: Material(
        color: RidoColors.surface,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 6, RidoSpacing.m, 6),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(
                width: 32,
                height: 32,
                child: CountdownRing(
                  key: ValueKey('chip-${r.id}'),
                  duration: left.isNegative ? const Duration(seconds: 1) : left,
                  running: true,
                  color: RidoColors.coral600,
                  trackColor: RidoColors.coral100,
                  size: 32,
                  strokeWidth: 3,
                  child: Icon(r.vehicle.icon, size: 16, color: RidoColors.coral600),
                ),
              ),
              const SizedBox(width: RidoSpacing.s),
              Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(formatInr(r.fare), style: t.bodySemibold.copyWith(height: 1.1)),
                Text('${formatKm(r.pickupDistanceKm)} away', style: t.caption.copyWith(color: RidoColors.navy700)),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}
