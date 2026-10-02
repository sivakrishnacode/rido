import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';
import 'package:tamiltaxi_ui/tamiltaxi_ui.dart';

import '../../state/driver_account.dart';
import '../../state/live_helpers.dart';
import 'driver_help_screen.dart';

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
        topics: driverHelpTopics(ref),
        initialTopic: topic,
        onSubmit: (topic, description) async {
          // The driver may leave while it sends: [ref] is gone by then, the container is not.
          final container = ProviderScope.containerOf(context, listen: false);
          try {
            await repo.raiseTicket(topic: topic, description: description);
          } on Exception catch (e) {
            if (context.mounted) showTtSnack(context, userMessage(e));
            return;
          }
          container.invalidate(driverTicketsProvider);
          if (!context.mounted) return;
          showTtSnack(context, 'Ticket raised. We usually reply within 24 hours.', success: true);
          if (context.canPop()) context.pop();
        },
      ),
    );
  }
}
