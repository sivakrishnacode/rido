import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

import 'request_layout.dart';

/// One open request in the comparison list, with when it closes.
typedef StackEntry = ({RideRequest request, DateTime expiresAt});

/// D-15 / D-20 with two or more open requests (like Namma Yatri's): a rail of countdown rings with each fare on the
/// left (tap to jump), and a card per request on the right to compare fare, ₹/km, pickup and trip side by side.
/// Each card has its own "Swipe to accept" and a ✕ to decline; the soonest to close is on top.
class RequestStackView extends StatefulWidget {
  const RequestStackView({
    super.key,
    required this.entries,
    required this.onAccept,
    required this.onDecline,
    required this.onExpired,
    this.acceptingId,
    this.delivery = false,
  });

  final List<StackEntry> entries;
  final ValueChanged<String> onAccept;
  final ValueChanged<String> onDecline;

  /// A card's ring ran out.
  final ValueChanged<String> onExpired;

  /// The request whose accept call is in flight.
  final String? acceptingId;
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
        backgroundColor: RidoColors.background,
        body: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(RidoSpacing.gutter, RidoSpacing.s, RidoSpacing.s, RidoSpacing.s),
              child: Row(children: [
                const Icon(Symbols.notifications_active_rounded, color: RidoColors.coral600, fill: 1, size: 26),
                const SizedBox(width: RidoSpacing.s),
                Expanded(
                  child: Text('${entries.length} ${widget.delivery ? 'delivery' : 'ride'} requests',
                      style: t.h2, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                const RequestVoiceToggle(dark: false),
              ]),
            ),
            Expanded(
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Rail: one ring per request, fare under it.
                SizedBox(
                  width: 76,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: RidoSpacing.s),
                    children: [
                      for (final e in entries)
                        _RailItem(
                          key: ValueKey('rail-${e.request.id}'),
                          request: e.request,
                          left: left(e),
                          onTap: () => _jumpTo(e.request.id),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(0, RidoSpacing.s, RidoSpacing.gutter, RidoSpacing.xl),
                    child: Column(children: [
                      for (final e in entries)
                        Padding(
                          key: _keyFor(e.request.id),
                          padding: const EdgeInsets.only(bottom: RidoSpacing.m),
                          child: _RequestCard(
                            key: ValueKey('card-${e.request.id}'),
                            request: e.request,
                            left: left(e),
                            accepting: widget.acceptingId == e.request.id,
                            locked: widget.acceptingId != null,
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
}

class _RailItem extends StatelessWidget {
  const _RailItem({super.key, required this.request, required this.left, required this.onTap});
  final RideRequest request;
  final Duration left;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Semantics(
      button: true,
      label: '${formatInr(request.fare)} request, pickup ${formatKm(request.pickupDistanceKm)} away. Show it',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: RidoRadii.cardRadius,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: RidoSpacing.s),
          child: Column(children: [
            DecoratedBox(
              decoration: const BoxDecoration(color: RidoColors.surface, shape: BoxShape.circle, boxShadow: RidoShadows.soft),
              child: CountdownRing(
                duration: left,
                size: 52,
                strokeWidth: 4,
                showBadge: false,
                color: RidoColors.coral600,
                trackColor: RidoColors.coral50,
                child: Icon(request.vehicle.icon, color: RidoColors.coral600, size: 22, fill: 1),
              ),
            ),
            const SizedBox(height: 4),
            Text(formatInr(request.fare), style: RidoTextStyles.tabular(t.bodySemibold)),
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
  });

  final RideRequest request;
  final Duration left;
  final bool accepting;

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
      padding: const EdgeInsets.fromLTRB(RidoSpacing.l, RidoSpacing.m, RidoSpacing.s, RidoSpacing.l),
      decoration: BoxDecoration(
        color: RidoColors.surface,
        borderRadius: const BorderRadius.all(Radius.circular(RidoRadii.sheet)),
        border: Border.all(color: RidoColors.divider),
        boxShadow: RidoShadows.soft,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Wrap(spacing: 6, runSpacing: 6, children: [
              _Tag(icon: Symbols.star_rounded, label: r.customerRating.toStringAsFixed(1), bg: RidoColors.warningTint, fg: RidoColors.warningText),
              _Tag(icon: r.vehicle.icon, label: r.vehicle.label, bg: RidoColors.infoTint, fg: RidoColors.navy900),
              if (r.isCustomerVerified)
                const _Tag(icon: Symbols.verified_rounded, label: 'Verified', bg: RidoColors.successTint, fg: RidoColors.successText),
              if (r.isWomenOnly)
                const _Tag(icon: Symbols.female_rounded, label: 'Butterfly', bg: RidoColors.butterfly50, fg: RidoColors.butterfly600),
              if (parcel != null)
                _Tag(icon: Symbols.package_2_rounded, label: '${parcel.category.label} · ${parcel.weight.label}', bg: RidoColors.coral50, fg: RidoColors.coral700),
            ]),
          ),
          // ✕ inside this request's ring.
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
                running: !locked,
                onFinished: onExpired,
                color: RidoColors.coral600,
                trackColor: RidoColors.divider,
                child: const Icon(Symbols.close_rounded, color: RidoColors.navy700, size: 22),
              ),
            ),
          ),
        ]),
        const SizedBox(height: RidoSpacing.s),
        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Text(formatInr(r.fare), style: RidoTextStyles.tabular(t.display)),
          if (perKm != null) ...[
            const SizedBox(width: RidoSpacing.s),
            Text('₹$perKm/km', style: t.bodySmall.copyWith(color: RidoColors.navy500)),
          ],
        ]),
        const SizedBox(height: RidoSpacing.m),
        _Stop(
          dot: RidoColors.success,
          headline: [
            '${formatKm(r.pickupDistanceKm)} away · ${r.pickupEtaMin} min',
            ?r.pickup.landmark,
          ].join(' · '),
          name: r.pickup.name,
          address: r.pickup.address,
          line: true,
        ),
        _Stop(
          dot: RidoColors.coral600,
          headline: '${formatKm(r.tripKm)} trip · ~${r.tripMin} min',
          name: r.drop.name,
          address: r.drop.address,
        ),
        const SizedBox(height: RidoSpacing.m),
        Padding(
          padding: const EdgeInsets.only(right: RidoSpacing.s),
          child: accepting
              ? const RidoButton(label: 'Accepting', height: 52, loading: true, onPressed: null)
              : SwipeToConfirm(
                  label: 'Swipe to accept',
                  height: 52,
                  enabled: !locked,
                  color: RidoColors.success,
                  knobColor: RidoColors.successText,
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
            if (line) Expanded(child: Container(width: 2, margin: const EdgeInsets.symmetric(vertical: 4), color: RidoColors.divider)),
          ]),
        ),
        const SizedBox(width: RidoSpacing.s),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: line ? RidoSpacing.m : 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(headline, style: t.bodySemibold),
              Text.rich(
                TextSpan(children: [
                  TextSpan(text: name, style: t.bodySmall.copyWith(color: RidoColors.navy900, fontWeight: FontWeight.w600)),
                  if (address.isNotEmpty && address != name)
                    TextSpan(text: ', $address', style: t.bodySmall.copyWith(color: RidoColors.navy500)),
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
