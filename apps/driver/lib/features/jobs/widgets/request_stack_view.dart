import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';
import 'package:tamiltaxi_ui/tamiltaxi_ui.dart';

import 'request_layout.dart';

/// One open request in the comparison list, with when it closes.
typedef StackEntry = ({RideRequest request, DateTime expiresAt});

/// What sets a request apart from the others open with it. The rail shows the first that applies (else the vehicle);
/// the card carries a tag with the same icon, so the rail can be read at a glance.
enum RequestPerk {
  /// Butterfly: a woman rider asked for a woman driver (first or only). The rail shows the butterfly on pink.
  butterfly('Butterfly', Symbols.female_rounded, TtColors.butterfly600, TtColors.butterfly50),

  /// A parcel among rides (a bike driver's mixed list).
  parcel('Parcel', Symbols.package_2_rounded, TtColors.coral700, TtColors.coral50),

  /// The highest ₹/km on the cards, when only one has it.
  bestRate('Best ₹/km', Symbols.trending_up_rounded, TtColors.successText, TtColors.successTint),

  /// The shortest ride to the pickup, when only one has it.
  closest('Closest pickup', Symbols.my_location_rounded, TtColors.navy900, TtColors.infoTint),
  verified('Verified', Symbols.verified_rounded, TtColors.successText, TtColors.successTint);

  const RequestPerk(this.label, this.icon, this.fg, this.bg);
  final String label;
  final IconData icon;
  final Color fg;
  final Color bg;

  /// Only makes sense next to the others (the card has no other tag for it).
  bool get comparative => this == bestRate || this == closest;
}

/// Each request's [RequestPerk]s by id, most telling first. Best ₹/km and closest pickup go to one request only, by
/// the numbers the cards show (a tie gives neither), and only when there are two or more to compare.
Map<String, List<RequestPerk>> requestPerks(List<RideRequest> requests) {
  String? only(num? Function(RideRequest) of, {required bool highest}) {
    final scored = [for (final r in requests) if (of(r) case final v?) (id: r.id, v: v)];
    if (scored.length < 2) return null;
    scored.sort((a, b) => highest ? b.v.compareTo(a.v) : a.v.compareTo(b.v));
    return scored[0].v != scored[1].v ? scored[0].id : null;
  }

  final mixed = requests.any((r) => r.isDelivery) && requests.any((r) => !r.isDelivery);
  final bestRate = only((r) => r.tripKm > 0 ? (r.fare / r.tripKm).round() : null, highest: true);
  final closest = only((r) => (r.pickupDistanceKm * 10).round(), highest: false);
  return {
    for (final r in requests)
      r.id: [
        if (r.isButterfly) RequestPerk.butterfly,
        if (mixed && r.isDelivery) RequestPerk.parcel,
        if (r.id == bestRate) RequestPerk.bestRate,
        if (r.id == closest) RequestPerk.closest,
        if (r.isCustomerVerified) RequestPerk.verified,
      ],
  };
}

/// D-15 / D-20 request screen (like Namma Yatri's): a card per open request to compare fare, ₹/km, pickup and trip
/// side by side, each with its own "Swipe to accept" and a ✕ to decline, soonest to close on top. With two or more a
/// rail of countdown rings with each fare sits on the left (tap to jump), each ring showing what sets that request
/// apart ([RequestPerk]); with one the card has the full width. The whole card also swipes: right accepts, left
/// declines. [directionBar] (Go To / Stay In) sits under the title.
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
    this.directionBar,
  });

  /// The Go To / Stay In bar: what is on and a way to change it without leaving the requests. Null in the
  /// background overlay (no app state there) and the Design gallery.
  final Widget? directionBar;

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
    final perks = requestPerks([for (final e in entries) e.request]);
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
            if (widget.directionBar case final bar?)
              Padding(
                padding: const EdgeInsets.fromLTRB(TtSpacing.gutter, 0, TtSpacing.gutter, TtSpacing.s),
                // Not while an accept is in flight: the screen is about to move on.
                child: IgnorePointer(ignoring: widget.acceptingId != null, child: bar),
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
                          perk: perks[e.request.id]?.firstOrNull,
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
                          child: _SwipeableCard(
                            enabled: widget.acceptingId == null,
                            onAccept: () => widget.onAccept(e.request.id),
                            onDecline: () => widget.onDecline(e.request.id),
                            child: _RequestCard(
                              key: ValueKey('card-${e.request.id}'),
                              request: e.request,
                              perks: [...?perks[e.request.id]],
                              left: left(e),
                              accepting: widget.acceptingId == e.request.id,
                              locked: widget.acceptingId != null,
                              running: widget.running,
                              onAccept: () => widget.onAccept(e.request.id),
                              onDecline: () => widget.onDecline(e.request.id),
                              onExpired: () => widget.onExpired(e.request.id),
                            ),
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
  const _RailItem({
    super.key,
    required this.request,
    required this.left,
    required this.onTap,
    this.perk,
    this.running = true,
  });
  final RideRequest request;

  /// Shown in the ring instead of the vehicle.
  final RequestPerk? perk;
  final Duration left;
  final bool running;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Semantics(
      button: true,
      label: '${formatInr(request.fare)} request${request.extra > 0 ? ' with ${formatInr(request.extra)} extra' : ''}, '
          '${perk == null ? '' : '${perk!.label}, '}pickup ${formatKm(request.pickupDistanceKm)} away. Show it',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: TtRadii.cardRadius,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: TtSpacing.s),
          child: Column(children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: perk == RequestPerk.butterfly ? TtColors.butterfly50 : TtColors.surface,
                shape: BoxShape.circle,
                boxShadow: TtShadows.soft,
              ),
              child: CountdownRing(
                duration: left,
                size: 52,
                strokeWidth: 4,
                showBadge: false,
                running: running,
                color: TtColors.coral600,
                trackColor: TtColors.coral50,
                child: perk == RequestPerk.butterfly
                    ? const ButterflyMark(size: 26)
                    : Icon(perk?.icon ?? request.vehicle.icon, color: perk?.fg ?? TtColors.coral600, size: 22, fill: 1),
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
    this.perks = const [],
    this.running = true,
  });

  final RideRequest request;

  /// Its tags for best ₹/km and closest pickup (the rail's icons).
  final List<RequestPerk> perks;
  final Duration left;
  final bool accepting;
  final bool running;

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
    final butterfly = r.isButterfly;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: TtColors.surface,
        borderRadius: const BorderRadius.all(Radius.circular(TtRadii.sheet)),
        border: Border.all(color: butterfly ? TtColors.butterfly400 : TtColors.divider, width: butterfly ? 1.5 : 1),
        boxShadow: TtShadows.soft,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (butterfly) _ButterflyBand(womenOnly: r.isWomenOnly),
        Padding(
          padding: EdgeInsets.fromLTRB(TtSpacing.l, butterfly ? TtSpacing.s : TtSpacing.m, TtSpacing.s, TtSpacing.l),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Wrap(spacing: 6, runSpacing: 6, children: [
                  _Tag(icon: Symbols.star_rounded, label: r.customerRating.toStringAsFixed(1), bg: TtColors.warningTint, fg: TtColors.warningText),
                  _Tag(icon: r.vehicle.icon, label: r.vehicle.label, bg: TtColors.infoTint, fg: TtColors.navy900),
                  for (final p in perks)
                    if (p.comparative) _Tag(icon: p.icon, label: p.label, bg: p.bg, fg: p.fg),
                  if (r.isCustomerVerified)
                    const _Tag(icon: Symbols.verified_rounded, label: 'Verified', bg: TtColors.successTint, fg: TtColors.successText),
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
        ),
      ]),
    );
  }
}

/// Butterfly: a pink band across the top of the card (a filled "Butterfly" badge and what the rider asked for), so a
/// women-rider request stands out in the list.
class _ButterflyBand extends StatelessWidget {
  const _ButterflyBand({required this.womenOnly});
  final bool womenOnly;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Container(
      color: TtColors.butterfly50,
      padding: const EdgeInsets.fromLTRB(TtSpacing.l, TtSpacing.s, TtSpacing.m, TtSpacing.s),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.fromLTRB(6, 3, 10, 3),
          decoration: const BoxDecoration(color: TtColors.butterfly600, borderRadius: TtRadii.pillRadius),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const ButterflyMark(size: 18, color: TtColors.surface, accent: TtColors.butterfly100),
            const SizedBox(width: 4),
            Text('Butterfly', style: t.caption.copyWith(color: TtColors.surface, fontWeight: FontWeight.w700)),
          ]),
        ),
        const SizedBox(width: TtSpacing.s),
        Expanded(
          child: Text(
            womenOnly ? 'Women drivers only' : 'Women drivers first',
            style: t.bodySmallMedium.copyWith(color: TtColors.butterfly600, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ]),
    );
  }
}

/// The whole card follows a sideways drag (like other ride apps): let go past a third of its width and right accepts,
/// left declines; short of that it springs back. "Accept" (green) or "Decline" (red) shows behind it, turning solid
/// with a tick of haptics once letting go would count. An accept springs back into place (the card then shows
/// "Accepting", and stays if the offer went to someone else); a decline slides the card out.
class _SwipeableCard extends StatefulWidget {
  const _SwipeableCard({required this.enabled, required this.onAccept, required this.onDecline, required this.child});
  final bool enabled;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final Widget child;

  @override
  State<_SwipeableCard> createState() => _SwipeableCardState();
}

class _SwipeableCardState extends State<_SwipeableCard> with SingleTickerProviderStateMixin {
  /// Share of the card's width to drag before letting go counts.
  static const _threshold = 0.35;

  /// The card's sideways offset (px).
  late final _dx = AnimationController.unbounded(vsync: this);
  double _width = 1;
  bool _armed = false;
  Timer? _comeBack;

  @override
  void dispose() {
    _comeBack?.cancel();
    _dx.dispose();
    super.dispose();
  }

  bool _past(double dx) => dx.abs() >= _width * _threshold;

  void _onUpdate(DragUpdateDetails d) {
    if (!widget.enabled) return;
    _dx.value += d.primaryDelta ?? 0;
    final armed = _past(_dx.value);
    if (armed != _armed) {
      _armed = armed;
      HapticFeedback.selectionClick();
    }
  }

  Future<void> _onEnd(DragEndDetails _) async {
    final dx = _dx.value;
    _armed = false;
    const back = Duration(milliseconds: 200);
    if (!widget.enabled || !_past(dx)) {
      await _dx.animateTo(0, duration: back, curve: Curves.easeOut);
    } else if (dx > 0) {
      HapticFeedback.mediumImpact();
      widget.onAccept();
      await _dx.animateTo(0, duration: back, curve: Curves.easeOut);
    } else {
      await _dx.animateTo(-_width * 1.1, duration: const Duration(milliseconds: 180), curve: Curves.easeIn);
      if (!mounted) return;
      widget.onDecline();
      // Normally the card is gone by now; if the decline didn't take, bring it back.
      _comeBack = Timer(const Duration(seconds: 1), () {
        if (mounted) _dx.animateTo(0, duration: back, curve: Curves.easeOut);
      });
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        _width = box.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragUpdate: widget.enabled ? _onUpdate : null,
          onHorizontalDragEnd: widget.enabled ? _onEnd : null,
          onHorizontalDragCancel: () => _dx.animateTo(0, duration: const Duration(milliseconds: 200)),
          child: AnimatedBuilder(
            animation: _dx,
            builder: (context, child) {
              final dx = _dx.value;
              // Always two children, so the card (its countdown rings) is never rebuilt from scratch.
              return Stack(children: [
                Positioned.fill(
                  child: dx == 0 ? const SizedBox.shrink() : _SwipeBackdrop(accept: dx > 0, armed: _past(dx)),
                ),
                Transform.translate(offset: Offset(dx, 0), child: child),
              ]);
            },
            child: widget.child,
          ),
        );
      });
}

/// What letting go does, behind the moving card: "Accept" on the left (dragging right), "Decline" on the right.
class _SwipeBackdrop extends StatelessWidget {
  const _SwipeBackdrop({required this.accept, required this.armed});
  final bool accept;
  final bool armed;

  @override
  Widget build(BuildContext context) {
    final solid = accept ? TtColors.success : TtColors.error;
    final fg = armed ? TtColors.surface : (accept ? TtColors.successText : TtColors.error);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      padding: const EdgeInsets.symmetric(horizontal: TtSpacing.xl),
      alignment: accept ? Alignment.centerLeft : Alignment.centerRight,
      decoration: BoxDecoration(
        color: armed ? solid : (accept ? TtColors.successTint : TtColors.errorTint),
        borderRadius: const BorderRadius.all(Radius.circular(TtRadii.sheet)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(accept ? Symbols.check_circle_rounded : Symbols.cancel_rounded, color: fg, fill: 1, size: 32),
        const SizedBox(height: TtSpacing.xs),
        Text(accept ? 'Accept' : 'Decline', style: context.type.bodySemibold.copyWith(color: fg)),
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
