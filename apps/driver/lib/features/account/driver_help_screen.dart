import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

import '../../router/routes.dart';
import '../../state/driver_account.dart';
import '../../state/driver_session.dart';

/// Account › Help & support (driver version of P-25): topics, latest trip, my tickets,
/// WhatsApp and Raise a ticket.
class DriverHelpScreen extends ConsumerWidget {
  const DriverHelpScreen({super.key, this.showcase = false});

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tickets = ref.watch(driverTicketsProvider);
    final trips = ref.watch(earningsProvider(EarningsPeriod.today)).value?.trips;
    final latest = (trips == null || trips.isEmpty) ? null : trips.first;
    return Scaffold(
      backgroundColor: RidoColors.background,
      appBar: const RidoAppBar(title: 'Help & support'),
      body: SupportHomeView(
        topics: ref.read(supportRepositoryProvider).topics(driver: true),
        tickets: tickets.hasError ? const [] : tickets.value,
        recentTrip: latest == null
            ? null
            : SupportTripRef(
                id: latest.id,
                title: '${latest.from} → ${latest.to}',
                subtitle: '${formatRelativeDay(latest.time, withTime: true)} · ${formatInr(latest.fare)}',
                icon: latest.isDelivery ? Symbols.local_shipping_rounded : Symbols.two_wheeler_rounded,
              ),
        onRecentTrip: latest == null ? null : () => context.push(Routes.newTicket(topic: 'Payment issue')),
        onTopic: (topic) => context.push(Routes.newTicket(topic: topic)),
        onRaiseTicket: () => context.push(Routes.newTicket()),
        onWhatsApp: () => showRidoSnack(context, 'Opening WhatsApp'),
      ),
    );
  }
}
