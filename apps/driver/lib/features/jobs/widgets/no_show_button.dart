import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tamiltaxi_ui/tamiltaxi_ui.dart';

/// The label of the "Passenger didn't come" button: a countdown until [noShowAt], then the action.
/// Null [noShowAt] (not known yet) shows the countdown text without a time.
/// [who]: "Passenger", or "Sender" at a parcel pickup.
String noShowLabel(
  DateTime? noShowAt,
  DateTime now, {
  String who = 'Passenger',
}) {
  if (noShowAt == null) return "$who didn't come? Wait at the pickup first";
  final left = noShowAt.difference(now);
  if (left <= Duration.zero) {
    return "$who didn't come? Cancel ${who == 'Passenger' ? 'ride' : 'job'}";
  }
  final s = left.inSeconds;
  return "$who didn't come? Cancel in ${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}";
}

/// At the pickup (D-17 / D-21): after the no-show wait the driver may cancel as "Passenger didn't come", which
/// doesn't count against them. Before that the button is off and counts down (the API enforces the wait too).
class NoShowButton extends StatefulWidget {
  const NoShowButton({
    super.key,
    required this.noShowAt,
    required this.onCancel,
    this.enabled = true,
    this.who = 'Passenger',
  });

  final String who;

  final DateTime? noShowAt;
  final VoidCallback onCancel;
  final bool enabled;

  @override
  State<NoShowButton> createState() => _NoShowButtonState();
}

class _NoShowButtonState extends State<NoShowButton> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      final at = widget.noShowAt;
      if (at != null && !at.isAfter(DateTime.now())) _tick?.cancel();
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final at = widget.noShowAt;
    final isOpen = at != null && !at.isAfter(now);
    return TtButton.text(
      label: noShowLabel(at, now, who: widget.who),
      onPressed: widget.enabled && isOpen ? widget.onCancel : null,
    );
  }
}
