import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';
import 'package:tamiltaxi_ui/tamiltaxi_ui.dart';

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
      backgroundColor: TtColors.background,
      appBar: const TtAppBar(title: 'Raise a ticket'),
      body: NewTicketView(
        topics: repo.topics(driver: true),
        initialTopic: topic,
        onSubmit: (topic, description) async {
          try {
            final ticket = await repo.raiseTicket(topic: topic, description: description);
            ref.invalidate(driverTicketsProvider);
            if (!context.mounted) return;
            showTtSnack(context, 'Ticket ${ticket.id} raised. We usually reply within 24 hours.', success: true);
            if (context.canPop()) context.pop();
          } on OfflineException {
            if (context.mounted) showTtSnack(context, "You're offline. Try again.");
          }
        },
      ),
    );
  }
}
