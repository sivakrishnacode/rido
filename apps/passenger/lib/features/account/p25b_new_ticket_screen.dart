import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

import '../../router/routes.dart';
import '../../state/passenger_session.dart';
import 'p25_help_screen.dart';

/// P-25b Raise a ticket: topic chips, the trip (preselected from [tripId], "Change" picks another),
/// what happened, an optional screenshot, and Submit. The new ticket shows in "My tickets" as Open.
class P25bNewTicketScreen extends ConsumerStatefulWidget {
  const P25bNewTicketScreen({super.key, this.topic, this.tripId, this.showcase = false});

  final String? topic;
  final String? tripId;

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  @override
  ConsumerState<P25bNewTicketScreen> createState() => _P25bNewTicketScreenState();
}

class _P25bNewTicketScreenState extends ConsumerState<P25bNewTicketScreen> {
  /// The design frame shows today's bike ride attached.
  late String? _tripId = widget.tripId ?? (widget.showcase ? 'RD-24091528' : null);

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.help());
    }
  }

  Future<void> _changeTrip(List<Trip> trips) async {
    final picked = await showRidoSheet<String>(
      context,
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Choose a trip', style: ctx.type.h2),
          const SizedBox(height: 8),
          for (final trip in trips.take(6))
            _TripOption(
              trip: trip,
              selected: trip.id == _tripId,
              onTap: () => Navigator.of(ctx).pop(trip.id),
            ),
        ],
      ),
    );
    if (picked != null && mounted) setState(() => _tripId = picked);
  }

  Future<void> _submit(String topic, String description) async {
    try {
      await ref.read(supportRepositoryProvider).raiseTicket(topic: topic, description: description, tripId: _tripId);
    } on OfflineException {
      if (mounted) showRidoSnack(context, "You're offline. Try again when you're connected.");
      return;
    }
    ref.invalidate(ticketsProvider);
    if (!mounted) return;
    showRidoSnack(context, 'Ticket raised. We usually reply within 24 hours.', success: true);
    _close();
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(tripHistoryProvider);
    final trips = history.value ?? const <Trip>[];
    Trip? trip;
    for (final t in trips) {
      if (t.id == _tripId) trip = t;
    }
    // Wait for the trip list before building the form, so the preselected trip (and its
    // default "Fare issue" topic) is there from the start.
    final waiting = _tripId != null && history.isLoading && !history.hasValue;

    return Scaffold(
      appBar: RidoAppBar(
        title: 'Raise a ticket',
        backIcon: Symbols.close_rounded,
        onBack: _close,
        bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider(height: 1)),
      ),
      backgroundColor: RidoColors.surface,
      body: waiting
          ? const Center(child: CircularProgressIndicator())
          : NewTicketView(
              topics: ref.read(supportRepositoryProvider).topics(driver: false),
              initialTopic: widget.topic,
              trip: trip == null ? null : supportTripRef(trip, withVehicle: true),
              onChangeTrip: trips.length > 1 ? () => _changeTrip(trips) : null,
              onSubmit: _submit,
            ),
    );
  }
}

class _TripOption extends StatelessWidget {
  const _TripOption({required this.trip, required this.selected, required this.onTap});
  final Trip trip;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final ref = supportTripRef(trip, withVehicle: true);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(color: RidoColors.coral50, borderRadius: RidoRadii.cardRadius),
              child: Icon(ref.icon, color: RidoColors.coral500, fill: 1),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ref.title, style: t.bodySemibold, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(ref.subtitle, style: t.bodySmall.copyWith(color: RidoColors.navy500)),
                ],
              ),
            ),
            if (selected) const Icon(Symbols.check_circle_rounded, fill: 1, color: RidoColors.coral600),
          ],
        ),
      ),
    );
  }
}
