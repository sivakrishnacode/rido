import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

import '../../state/driver_session.dart';
import 'widgets/job_common.dart';

/// Chat with the passenger (driver side of P-14): seeded messages, quick replies, and a
/// seeded passenger reply a moment after each message.
class DriverChatScreen extends ConsumerStatefulWidget {
  const DriverChatScreen({super.key, this.showcase = false});

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  @override
  ConsumerState<DriverChatScreen> createState() => _DriverChatScreenState();
}

class _DriverChatScreenState extends ConsumerState<DriverChatScreen> {
  static const _quickReplies = [
    "I'm at the pickup point",
    'Coming in 2 minutes',
    'Stuck in traffic, reaching soon',
    'Please come to the main gate',
  ];

  late final RideRequest _job = ref.read(driverSessionProvider).job ?? Seed.rideRequest;
  late final List<ChatMessage> _messages = [
    for (final m in Seed.chatSeed()) m.copyWith(fromMe: !m.fromMe),
  ];
  final List<Timer> _timers = [];
  int _replyIndex = 0;

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    super.dispose();
  }

  void _send(String text) {
    setState(() => _messages.add(
        ChatMessage(id: 'd${_messages.length}', text: text, fromMe: true, sentAt: RidoClock.now())));
    final delay = ref.read(simTimingProvider)(SimTimings.chatReply);
    _timers.add(Timer(delay, () {
      if (!mounted) return;
      final reply = Seed.passengerReplies[_replyIndex++ % Seed.passengerReplies.length];
      setState(() => _messages.add(
          ChatMessage(id: 'p${_messages.length}', text: reply, fromMe: false, sentAt: RidoClock.now())));
    }));
  }

  @override
  Widget build(BuildContext context) => ChatScaffold(
        peerName: _job.customerName,
        peerInitials: initialsOf(_job.customerName),
        messages: List.unmodifiable(_messages),
        quickReplies: _quickReplies,
        onSend: _send,
        onCall: () => showRidoSnack(context, 'Calling ${_job.customerName} (number hidden)'),
        stripIcon: Symbols.location_on_rounded,
        stripText: 'Pickup: ${_job.pickup.name}',
      );
}
