import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

import '../../common/launch.dart';
import '../../state/driver_session.dart';
import '../../state/live_helpers.dart';
import 'widgets/job_common.dart';

/// Chat with the passenger (driver side of P-14): seeded messages, quick replies, and a
/// seeded passenger reply a moment after each message.
/// Live API: the trip's real chat (history, then new messages over the socket); Call dials the passenger.
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

  /// Live API only when there is a real job to chat about.
  late final bool _api = !widget.showcase && ref.read(isLiveApiProvider) && ref.read(driverSessionProvider).job != null;
  late final List<ChatMessage> _messages = _api
      ? []
      : [
          for (final m in Seed.chatSeed()) m.copyWith(fromMe: !m.fromMe),
        ];
  final List<Timer> _timers = [];
  StreamSubscription<ChatMessage>? _incoming;
  int _replyIndex = 0;

  @override
  void initState() {
    super.initState();
    if (_api) _connect();
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    _incoming?.cancel();
    super.dispose();
  }

  Future<void> _connect() async {
    final jobs = ref.read(liveJobsProvider);
    _incoming = jobs.messages(_job.id).listen(_add, onError: (Object _) {});
    try {
      final history = await jobs.chatHistory(_job.id);
      if (!mounted) return;
      for (final m in history) {
        _add(m);
      }
    } catch (e) {
      if (mounted && e is Exception) showRidoSnack(context, userMessage(e));
    }
  }

  /// Adds [m] once (the socket also echoes the driver's own messages), in time order.
  void _add(ChatMessage m) {
    if (!mounted || (m.id.isNotEmpty && _messages.any((x) => x.id == m.id))) return;
    setState(() {
      _messages.add(m);
      _messages.sort((a, b) => a.sentAt.compareTo(b.sentAt));
    });
  }

  Future<void> _sendLive(String text) async {
    try {
      _add(await ref.read(liveJobsProvider).sendMessage(_job.id, text));
    } on Exception catch (e) {
      if (mounted) showRidoSnack(context, userMessage(e));
    }
  }

  void _send(String text) {
    if (_api) {
      _sendLive(text);
      return;
    }
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
        onCall: () => _api
            ? dialNumber(context, _job.customerPhone, name: _job.customerName)
            : showRidoSnack(context, 'Calling ${_job.customerName} (number hidden)'),
        stripIcon: Symbols.location_on_rounded,
        stripText: 'Pickup: ${_job.pickup.name}',
      );
}
