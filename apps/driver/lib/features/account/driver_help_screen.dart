import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';
import 'package:tamiltaxi_ui/tamiltaxi_ui.dart';

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
      backgroundColor: TtColors.background,
      appBar: const TtAppBar(title: 'Help & support'),
      body: SupportHomeView(
        topics: driverHelpTopics(ref),
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
        onWhatsApp: () => showTtSnack(context, 'Opening WhatsApp'),
      ),
    );
  }
}

/// The driver's help topics, without "Plan & Autopay" while paid plans are off (the app is free).
List<String> driverHelpTopics(WidgetRef ref) {
  final plansOn = ref.watch(driverPlansEnabledProvider);
  return [
    for (final t in ref.read(supportRepositoryProvider).topics(driver: true))
      if (plansOn || t != 'Plan & Autopay') t,
  ];
}
