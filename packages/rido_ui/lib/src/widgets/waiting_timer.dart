import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:rido_data/rido_data.dart';

import '../format.dart';
import '../theme/rido_colors.dart';
import '../theme/rido_tokens.dart';

/// What the waiting chip says at [now]: free minutes left, then the charge so far.
({String title, String detail, bool isCharging}) waitingLabel(WaitingTerms w, DateTime now) {
  if (w.isFree) return (title: 'Waiting at the pickup', detail: 'No waiting charge', isCharging: false);
  final left = w.freeLeft(now);
  if (left > Duration.zero) {
    return (
      title: 'Free waiting · ${formatCountdown(left)} left',
      detail: 'Then ${formatInr(w.perMin)}/min, up to ${formatInr(w.maxCharge)}',
      isCharging: false,
    );
  }
  final charge = w.chargeAt(now);
  return (
    title: 'Waiting charge ${formatInr(charge)}',
    detail: charge >= w.maxCharge ? 'Maximum reached' : '${formatInr(w.perMin)} per started minute, up to ${formatInr(w.maxCharge)}',
    isCharging: true,
  );
}

/// "Waiting" chip at the pickup (P-15 for the passenger, D-17 for the driver): counts the free minutes down after
/// the driver arrives, then shows the waiting charge adding up. The server charges it when the ride starts.
class WaitingTimerChip extends StatefulWidget {
  const WaitingTimerChip({super.key, required this.terms, this.clock, this.isTicking = true});

  final WaitingTerms terms;

  /// False in the design gallery (a still frame, no timer).
  final bool isTicking;

  /// For tests; defaults to [DateTime.now].
  final DateTime Function()? clock;

  @override
  State<WaitingTimerChip> createState() => _WaitingTimerChipState();
}

class _WaitingTimerChipState extends State<WaitingTimerChip> {
  Timer? _tick;

  DateTime get _now => (widget.clock ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    if (!widget.isTicking) return;
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      // Nothing changes any more once the cap is reached.
      if (widget.terms.isFree || widget.terms.chargeAt(_now) >= widget.terms.maxCharge) _tick?.cancel();
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final l = waitingLabel(widget.terms, _now);
    final fg = l.isCharging ? RidoColors.warningText : RidoColors.navy900;
    return Semantics(
      liveRegion: true,
      label: '${l.title}. ${l.detail}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: l.isCharging ? RidoColors.warningTint : RidoColors.inputBg,
          borderRadius: RidoRadii.cardRadius,
        ),
        child: Row(children: [
          Icon(
            l.isCharging ? Symbols.hourglass_bottom_rounded : Symbols.timer_rounded,
            size: 22,
            color: l.isCharging ? RidoColors.warningText : RidoColors.coral600,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.title, style: RidoTextStyles.tabular(t.bodySemibold.copyWith(color: fg))),
              Text(l.detail, style: t.caption.copyWith(color: l.isCharging ? RidoColors.warningText : RidoColors.navy500)),
            ]),
          ),
        ]),
      ),
    );
  }
}
