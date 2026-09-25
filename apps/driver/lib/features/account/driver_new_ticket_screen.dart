import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

import '../../state/driver_account.dart';

/// Account › Raise a ticket: topic chips + description → "My tickets" as Open.
class DriverNewTicketScreen extends ConsumerWidget {
  const DriverNewTicketScreen({super.key, this.topic, this.showcase = false});

  final String? topic;

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(supportRepositoryProvider);
    return Scaffold(
      backgroundColor: RidoColors.background,
      appBar: const RidoAppBar(title: 'Raise a ticket'),
      body: NewTicketView(
        topics: repo.topics(driver: true),
        initialTopic: topic,
        onSubmit: (topic, description) async {
          try {
            final ticket = await repo.raiseTicket(topic: topic, description: description);
            ref.invalidate(driverTicketsProvider);
            if (!context.mounted) return;
            showRidoSnack(context, 'Ticket ${ticket.id} raised. We usually reply within 24 hours.', success: true);
            if (context.canPop()) context.pop();
          } on OfflineException {
            if (context.mounted) showRidoSnack(context, "You're offline. Try again.");
          }
        },
      ),
    );
  }
}
