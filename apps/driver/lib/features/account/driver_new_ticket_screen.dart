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
  const DriverNewTicketScreen({
    super.key,
    this.topic,
    this.tripId,
    this.showcase = false,
  });

  final String? topic;
  final String? tripId;

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(supportRepositoryProvider);
    Future<void> submit(
      String topic,
      String description, [
      PhotoAttachment? photo,
    ]) async {
      if (showcase) return showTtSnack(context, 'Design preview');
      final container = ProviderScope.containerOf(context, listen: false);
      final messenger = ScaffoldMessenger.of(context);
      SupportTicket ticket;
      try {
        ticket = await repo.raiseTicket(
          topic: topic,
          description: description,
          tripId: tripId,
        );
      } catch (e) {
        if (context.mounted) {
          showTtSnack(
            context,
            e is Exception
                ? userMessage(e)
                : 'Could not raise ticket. Try again.',
          );
        }
        return;
      }
      bool photoFailed = false;
      if (photo != null) {
        try {
          await repo.uploadAttachment(ticket.id, photo.bytes, photo.name);
        } catch (_) {
          photoFailed = true;
        }
      }
      container.invalidate(driverTicketsProvider);
      if (!context.mounted) return;
      if (context.canPop()) context.pop();
      if (photoFailed && photo != null) {
        messenger.showSnackBar(
          SnackBar(
            content: const Text(
              'Ticket raised, but the photo could not upload.',
            ),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () async {
                try {
                  await repo.uploadAttachment(
                    ticket.id,
                    photo.bytes,
                    photo.name,
                  );
                } catch (_) {
                  if (messenger.mounted) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Photo upload failed. Try again when connected.',
                        ),
                      ),
                    );
                  }
                }
              },
            ),
          ),
        );
      } else {
        showTtSnack(
          context,
          'Ticket raised. We usually reply within 24 hours.',
          success: true,
        );
      }
    }

    return Scaffold(
      backgroundColor: TtColors.background,
      appBar: const TtAppBar(title: 'Raise a ticket'),
      body: NewTicketView(
        topics: driverHelpTopics(ref),
        initialTopic: topic,
        onSubmit: submit,
        onSubmitWithPhoto: submit,
      ),
    );
  }
}
