import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';
import 'package:tamiltaxi_ui/tamiltaxi_ui.dart';

import '../../common/launch.dart';
import '../../router/routes.dart';
import '../../state/driver_account.dart';
import '../../state/driver_session.dart';

/// Account › Help & support (driver version of P-25): topics, latest trip, my tickets, WhatsApp, Raise a ticket and
/// (app bar) Call support. WhatsApp and Call use the support number from the app config.
class DriverHelpScreen extends ConsumerWidget {
  const DriverHelpScreen({super.key, this.showcase = false});

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tickets = ref.watch(driverTicketsProvider);
    final trips = ref.watch(earningsProvider(EarningsPeriod.today)).value?.trips;
    final latest = (trips == null || trips.isEmpty) ? null : trips.first;
    final vehicle = ref.watch(driverProfileProvider).value?.vehicleKind;
    final supportPhone = (ref.watch(appConfigProvider).value ?? AppConfig.fallback).supportPhone;

    void inert() => showTtSnack(context, 'Design preview: nothing opens');
    return Scaffold(
      backgroundColor: TtColors.background,
      appBar: TtAppBar(
        title: 'Help & support',
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: TtSpacing.s),
            child: TextButton.icon(
              onPressed: showcase
                  ? inert
                  : () => dialNumber(context, supportPhone, name: 'support'),
              icon: const Icon(Symbols.call_rounded, fill: 1),
              label: const Text('Call'),
              style: TextButton.styleFrom(
                foregroundColor: TtColors.coral600,
                minimumSize: const Size(48, 48),
              ),
            ),
          ),
        ],
      ),
      body: SupportHomeView(
        topics: driverHelpTopics(ref),
        tickets: tickets.value,
        ticketsError: tickets.hasError
            ? 'Could not load tickets. Try again.'
            : null,
        onRetryTickets: () => ref.invalidate(driverTicketsProvider),
        recentTrip: latest == null
            ? null
            : SupportTripRef(
                id: latest.id,
                title: '${latest.from} → ${latest.to}',
                subtitle:
                    '${formatRelativeDay(latest.time, withTime: true)} · ${formatInr(latest.fare)}',
                // The driver's own vehicle did the trip.
                icon:
                    vehicle?.icon ??
                    (latest.isDelivery
                        ? Symbols.local_shipping_rounded
                        : Symbols.two_wheeler_rounded),
              ),
        // The ticket names the trip, so support knows which one.
        onRecentTrip: latest == null
            ? null
            : (showcase
                  ? inert
                  : () => context.push(
                      Routes.newTicket(
                        topic: 'Payment issue',
                        tripId: latest.id,
                      ),
                    )),
        onTopic: (topic) =>
            showcase ? inert() : context.push(Routes.newTicket(topic: topic)),
        onRaiseTicket: showcase
            ? inert
            : () => context.push(Routes.newTicket()),
        onWhatsApp: showcase
            ? inert
            : () => openWhatsAppChat(context, supportPhone),
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
