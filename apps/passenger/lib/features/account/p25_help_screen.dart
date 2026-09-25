import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

import '../../router/routes.dart';
import '../../state/passenger_session.dart';
import '../states/s04_no_internet_screen.dart';

/// A trip as a help shortcut: "Gandhipuram → Brookefields · Today, 3:28 PM · ₹38".
SupportTripRef supportTripRef(Trip trip, {bool withVehicle = false}) => SupportTripRef(
      id: trip.id,
      title: '${trip.fromLabel} → ${trip.toLabel}',
      subtitle: [
        formatRelativeDay(trip.startedAt, withTime: true),
        if (withVehicle) trip.isParcel ? 'Parcel' : trip.vehicle.label,
        formatInr(trip.fare),
      ].join(' · '),
      icon: trip.isParcel ? Symbols.package_2_rounded : trip.vehicle.icon,
    );

/// P-25 Help & support: search, recent trip shortcut, topics, "My tickets", WhatsApp and
/// Raise a ticket. [tripId] (from P-22) is carried into the new ticket.
class P25HelpScreen extends ConsumerWidget {
  const P25HelpScreen({super.key, this.tripId, this.showcase = false});

  final String? tripId;

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tickets = ref.watch(ticketsProvider);
    final history = ref.watch(tripHistoryProvider);
    final trips = history.value ?? const <Trip>[];
    Trip? recent;
    for (final t in trips) {
      if (t.id == tripId) recent = t;
    }
    recent ??= trips.isEmpty ? null : trips.first;

    final offline = tickets.error is OfflineException;
    return Scaffold(
      appBar: const RidoAppBar(title: 'Help & support'),
      body: offline
          ? S04NoInternetView(onRetry: () {
              ref.invalidate(ticketsProvider);
              ref.invalidate(tripHistoryProvider);
            })
          : SupportHomeView(
              topics: ref.read(supportRepositoryProvider).topics(driver: false),
              tickets: tickets.value,
              recentTrip: recent == null ? null : supportTripRef(recent),
              onRecentTrip: recent == null ? null : () => context.push(Routes.newTicket(tripId: recent!.id)),
              onTopic: (topic) => context.push(Routes.newTicket(topic: topic, tripId: tripId)),
              onRaiseTicket: () => context.push(Routes.newTicket(tripId: tripId)),
              onWhatsApp: () => showRidoSnack(context, 'Opening WhatsApp'),
            ),
    );
  }
}
