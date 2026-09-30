import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';
import 'package:tamiltaxi_ui/tamiltaxi_ui.dart';

import 'request_layout.dart';

/// One open request in the comparison list, with when it closes.
typedef StackEntry = ({RideRequest request, DateTime expiresAt});

/// D-15 / D-20 request screen (like Namma Yatri's): a card per open request to compare fare, ₹/km, pickup and trip
/// side by side, each with its own "Swipe to accept" and a ✕ to decline, soonest to close on top. With two or more a
/// rail of countdown rings with each fare sits on the left (tap to jump); with one the card has the full width.
class RequestStackView extends StatefulWidget {
  const RequestStackView({
    super.key,
    required this.entries,
    required this.onAccept,
    required this.onDecline,
    required this.onExpired,
    this.acceptingId,
    this.delivery = false,
    this.showVoiceToggle = true,
    this.topRight,
    this.running = true,
    this.direction,
  });

  /// Go To / Stay In is on: "Towards Home" / "Inside RS Puram" on every card (dispatch only sends trips that fit).
  final String? direction;

  /// False freezes the rings (design gallery).
  final bool running;

  /// False in the background overlay (its own isolate, no app state).
  final bool showVoiceToggle;

  /// Replaces the voice toggle (the overlay's "close and open Tamil Taxi").
  final Widget? topRight;

  final List<StackEntry> entries;
  final ValueChanged<String> onAccept;
  final ValueChanged<String> onDecline;

  /// A card's ring ran out.
  final ValueChanged<String> onExpired;

  /// The request whose accept call is in flight.
  final String? acceptingId;

  /// The screen was opened for a delivery (a bike driver's stack can mix rides and parcels: the title follows them).
  final bool delivery;

  @override
  State<RequestStackView> createState() => _RequestStackViewState();
}

class _RequestStackViewState extends State<RequestStackView> {
  final _keys = <String, GlobalKey>{};

  GlobalKey _keyFor(String id) => _keys.putIfAbsent(id, GlobalKey.new);

  void _jumpTo(String id) {
    final ctx = _keyFor(id).currentContext;
    if (ctx != null) Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 250), alignment: 0.05);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final entries = [...widget.entries]..sort((a, b) => a.expiresAt.compareTo(b.expiresAt));
    final now = DateTime.now();
    Duration left(StackEntry e) {
      final d = e.expiresAt.difference(now);
      return d < const Duration(seconds: 1) ? const Duration(seconds: 1) : d;
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: TtColors.background,
        body: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(TtSpacing.gutter, TtSpacing.s, TtSpacing.s, TtSpacing.s),
              child: Row(children: [
                const Icon(Symbols.notifications_active_rounded, color: TtColors.coral600, fill: 1, size: 26),
                const SizedBox(width: TtSpacing.s),
                Expanded(
                  child: Text(_title(entries), style: t.h2, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                if (widget.showVoiceToggle) const RequestVoiceToggle(dark: false),
                ?widget.topRight,
              ]),
            ),
            Expanded(
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Rail: one ring per request, fare under it (only when there is something to compare).
                if (entries.length > 1)
                  SizedBox(
                  width: 76,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: TtSpacing.s),
                    children: [
                      for (final e in entries)
                        _RailItem(
                          key: ValueKey('rail-${e.request.id}'),
                          request: e.request,
                          left: left(e),
                          running: widget.running,
                          onTap: () => _jumpTo(e.request.id),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                        entries.length > 1 ? 0 : TtSpacing.gutter, TtSpacing.s, TtSpacing.gutter, TtSpacing.xl),
                    child: Column(children: [
                      for (final e in entries)
                        Padding(
                          key: _keyFor(e.request.id),
                          padding: const EdgeInsets.only(bottom: TtSpacing.m),
                          child: _RequestCard(
                            key: ValueKey('card-${e.request.id}'),
                            request: e.request,
                            direction: widget.direction,
                            left: left(e),
                            accepting: widget.acceptingId == e.request.id,
                            locked: widget.acceptingId != null,
                            running: widget.running,
                            onAccept: () => widget.onAccept(e.request.id),
                            onDecline: () => widget.onDecline(e.request.id),
                            onExpired: () => widget.onExpired(e.request.id),
                          ),
                        ),
                    ]),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  /// "New ride request", "2 delivery requests", or "3 requests" when rides and parcels are mixed.
  String _title(List<StackEntry> entries) {
    final deliveries = entries.where((e) => e.request.isDelivery).length;
    final kind = entries.isEmpty
        ? (widget.delivery ? 'delivery ' : 'ride ')
        : deliveries == entries.length
            ? 'delivery '
            : deliveries == 0
                ? 'ride '
                : '';
    return entries.length <= 1 ? 'New ${kind}request' : '${entries.length} ${kind}requests';
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({super.key, required this.request, required this.left, required this.onTap, this.running = true});
  final RideRequest request;
  final Duration left;
  final bool running;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Semantics(
      button: true,
      label: '${formatInr(request.fare)} request${request.extra > 0 ? ' with ${formatInr(request.extra)} extra' : ''}, '
          'pickup ${formatKm(request.pickupDistanceKm)} away. Show it',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: TtRadii.cardRadius,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: TtSpacing.s),
          child: Column(children: [
            DecoratedBox(
              decoration: const BoxDecoration(color: TtColors.surface, shape: BoxShape.circle, boxShadow: TtShadows.soft),
              child: CountdownRing(
                duration: left,
                size: 52,
                strokeWidth: 4,
                showBadge: false,
                running: running,
                color: TtColors.coral600,
                trackColor: TtColors.coral50,
                child: Icon(request.vehicle.icon, color: TtColors.coral600, size: 22, fill: 1),
              ),
            ),
            const SizedBox(height: 4),
            Text(formatInr(request.fare - request.extra), style: TtTextStyles.tabular(t.bodySemibold)),
            if (request.extra > 0)
              Text('+${formatInr(request.extra)}',
                  style: TtTextStyles.tabular(t.caption.copyWith(color: TtColors.successText, fontWeight: FontWeight.w700))),
          ]),
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    super.key,
    required this.request,
    required this.left,
    required this.accepting,
    required this.locked,
    required this.onAccept,
    required this.onDecline,
    required this.onExpired,
    this.running = true,
    this.direction,
  });

  final RideRequest request;
  final Duration left;
  final bool accepting;
  final bool running;
  final String? direction;

  /// Another request is being accepted: no actions here meanwhile.
  final bool locked;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onExpired;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final r = request;
    final perKm = r.tripKm > 0 ? (r.fare / r.tripKm).round() : null;
    final parcel = r.parcel;
    return Container(
      padding: const EdgeInsets.fromLTRB(TtSpacing.l, TtSpacing.m, TtSpacing.s, TtSpacing.l),
      decoration: BoxDecoration(
        color: TtColors.surface,
        borderRadius: const BorderRadius.all(Radius.circular(TtRadii.sheet)),
        border: Border.all(color: TtColors.divider),
        boxShadow: TtShadows.soft,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Wrap(spacing: 6, runSpacing: 6, children: [
              _Tag(icon: Symbols.star_rounded, label: r.customerRating.toStringAsFixed(1), bg: TtColors.warningTint, fg: TtColors.warningText),
              _Tag(icon: r.vehicle.icon, label: r.vehicle.label, bg: TtColors.infoTint, fg: TtColors.navy900),
              if (r.isCustomerVerified)
                const _Tag(icon: Symbols.verified_rounded, label: 'Verified', bg: TtColors.successTint, fg: TtColors.successText),
              if (direction != null)
                _Tag(icon: Symbols.near_me_rounded, label: direction!, bg: TtColors.successTint, fg: TtColors.successText),
              if (r.isWomenOnly)
                const _Tag(icon: Symbols.female_rounded, label: 'Butterfly', bg: TtColors.butterfly50, fg: TtColors.butterfly600),
              if (parcel != null) ...[
                _Tag(icon: Symbols.package_2_rounded, label: '${parcel.category.label} · ${parcel.weight.label}', bg: TtColors.coral50, fg: TtColors.coral700),
                _Tag(
                  icon: Symbols.person_pin_circle_rounded,
                  label: 'Paid by ${parcel.payer == ParcelPayer.receiver ? 'receiver' : 'sender'}',
                  bg: TtColors.inputBg,
                  fg: TtColors.navy900,
                ),
              ],
            ]),
          ),
          // ✕ inside this request's ring, the seconds left under it.
          Column(mainAxisSize: MainAxisSize.min, children: [
          Semantics(
            button: true,
            label: 'Decline ${formatInr(r.fare)} request',
            excludeSemantics: true,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: locked ? null : onDecline,
              child: CountdownRing(
                duration: left,
                size: 44,
                strokeWidth: 3,
                showBadge: false,
                running: running && !locked,
                onFinished: onExpired,
                color: TtColors.coral600,
                trackColor: TtColors.divider,
                child: const Icon(Symbols.close_rounded, color: TtColors.navy700, size: 22),
              ),
            ),
          ),
          SecondsLeft(left: left, running: running && !locked),
          ]),
        ]),
        const SizedBox(height: TtSpacing.s),
        // "₹50 + ₹20": the rider's extra in green after the fare (₹/km is on the whole amount).
        Wrap(crossAxisAlignment: WrapCrossAlignment.end, spacing: TtSpacing.s, children: [
          Text.rich(
            TextSpan(children: [
              TextSpan(text: formatInr(r.fare - r.extra)),
              if (r.extra > 0) TextSpan(text: ' + ${formatInr(r.extra)}', style: const TextStyle(color: TtColors.success)),
            ]),
            style: TtTextStyles.tabular(t.display),
          ),
          if (perKm != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('₹$perKm/km', style: t.bodySmall.copyWith(color: TtColors.navy500)),
            ),
        ]),
        if (r.extra > 0) ...[
          const SizedBox(height: TtSpacing.xs),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: TtSpacing.s, vertical: 6),
            decoration: const BoxDecoration(color: TtColors.successTint, borderRadius: TtRadii.cardRadius),
            child: Row(children: [
              const Icon(Symbols.add_circle_rounded, size: 18, color: TtColors.successText, fill: 1),
              const SizedBox(width: TtSpacing.s),
              Expanded(
                child: Text('${r.isDelivery ? 'Sender' : 'Rider'} added ${formatInr(r.extra)} extra',
                    style: t.bodySmallMedium.copyWith(color: TtColors.successText, fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
        ],
        const SizedBox(height: TtSpacing.m),
        _Stop(
          dot: TtColors.success,
          headline: [
            '${formatKm(r.pickupDistanceKm)} away · ${r.pickupEtaMin} min',
            ?r.pickup.landmark,
          ].join(' · '),
          name: r.pickup.name,
          address: r.pickup.address,
          line: true,
        ),
        _Stop(
          dot: TtColors.coral600,
          headline: '${formatKm(r.tripKm)} trip · ~${r.tripMin} min',
          name: r.drop.name,
          address: r.drop.address,
        ),
        const SizedBox(height: TtSpacing.s),
        Text(
          [r.customerName, if (r.bookedBy != null) 'booked by ${r.bookedBy}', 'Cash / UPI to you'].join(' · '),
          style: t.caption.copyWith(color: TtColors.navy500),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: TtSpacing.m),
        Padding(
          padding: const EdgeInsets.only(right: TtSpacing.s),
          child: accepting
              ? const TtButton(label: 'Accepting', height: 52, loading: true, onPressed: null)
              : SwipeToConfirm(
                  label: 'Swipe to accept',
                  height: 52,
                  enabled: !locked,
                  color: TtColors.success,
                  knobColor: TtColors.successText,
                  onConfirmed: onAccept,
                ),
        ),
      ]),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.icon, required this.label, required this.bg, required this.fg});
  final IconData icon;
  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: const BorderRadius.all(Radius.circular(6))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: fg, fill: 1),
          const SizedBox(width: 4),
          Text(label, style: context.type.caption.copyWith(color: fg, fontWeight: FontWeight.w600)),
        ]),
      );
}

/// A pickup / drop line: "0.8 km away · 3 min" in bold, then the place and its address.
class _Stop extends StatelessWidget {
  const _Stop({required this.dot, required this.headline, required this.name, required this.address, this.line = false});
  final Color dot;
  final String headline;
  final String name;
  final String address;
  final bool line;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          width: 20,
          child: Column(children: [
            const SizedBox(height: 5),
            Container(width: 10, height: 10, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
            if (line) Expanded(child: Container(width: 2, margin: const EdgeInsets.symmetric(vertical: 4), color: TtColors.divider)),
          ]),
        ),
        const SizedBox(width: TtSpacing.s),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: line ? TtSpacing.m : 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(headline, style: t.bodySemibold),
              Text.rich(
                TextSpan(children: [
                  TextSpan(text: name, style: t.bodySmall.copyWith(color: TtColors.navy900, fontWeight: FontWeight.w600)),
                  if (address.isNotEmpty && address != name)
                    TextSpan(text: ', $address', style: t.bodySmall.copyWith(color: TtColors.navy500)),
                ]),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

/// "12s": seconds until the request closes, ticking once a second (red for the last 5).
class SecondsLeft extends StatefulWidget {
  const SecondsLeft({super.key, required this.left, this.running = true});
  final Duration left;
  final bool running;

  @override
  State<SecondsLeft> createState() => _SecondsLeftState();
}

class _SecondsLeftState extends State<SecondsLeft> {
  late int _secs = (widget.left.inMilliseconds / 1000).ceil();
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    if (widget.running) {
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted && _secs > 0) setState(() => _secs--);
      });
    }
  }

  @override
  void didUpdateWidget(SecondsLeft old) {
    super.didUpdateWidget(old);
    if (!widget.running) {
      _tick?.cancel();
      _tick = null;
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final secs = _secs;
    return ExcludeSemantics(
      child: Text(
        '${secs}s',
        style: TtTextStyles.tabular(context.type.bodySmallMedium)
            .copyWith(color: secs <= 5 ? TtColors.error : TtColors.navy700),
      ),
    );
  }
}
