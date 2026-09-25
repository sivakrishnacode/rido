import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

import '../../common/async_view.dart';
import '../../router/routes.dart';
import '../../state/passenger_session.dart';
import '../states/s06_empty_activity_screen.dart';
import '../states/s07b_activity_skeleton.dart';
import 'widgets/activity_header.dart';

/// P-21 Activity: All · Rides · Parcels tabs over the trip history (newest first).
/// Loading shows the S-07b skeleton, no trips shows S-06, offline shows S-04.
class P21ActivityScreen extends ConsumerStatefulWidget {
  const P21ActivityScreen({super.key, this.showcase = false});

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  @override
  ConsumerState<P21ActivityScreen> createState() => _P21ActivityScreenState();
}

class _P21ActivityScreenState extends ConsumerState<P21ActivityScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: activityTabs.length, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  List<Trip> _filter(List<Trip> trips, int tab) => switch (tab) {
        1 => trips.where((t) => !t.isParcel).toList(),
        2 => trips.where((t) => t.isParcel).toList(),
        _ => trips,
      };

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(tripHistoryProvider);
    return Scaffold(
      body: Column(
        children: [
          ActivityHeader(controller: _tabs),
          Expanded(
            child: AsyncView<List<Trip>>(
              value: history,
              onRetry: () => ref.invalidate(tripHistoryProvider),
              loading: const S07bActivitySkeleton(),
              data: (trips) => TabBarView(
                controller: _tabs,
                children: [
                  for (var i = 0; i < activityTabs.length; i++)
                    _TripList(
                      trips: _filter(trips, i),
                      emptyTitle: switch (i) {
                        1 => 'No rides yet',
                        2 => 'No parcels yet',
                        _ => 'No trips yet',
                      },
                      onRefresh: () => ref.refresh(tripHistoryProvider.future),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TripList extends StatelessWidget {
  const _TripList({required this.trips, required this.emptyTitle, required this.onRefresh});

  final List<Trip> trips;
  final String emptyTitle;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (trips.isEmpty) {
      return S06EmptyActivityView(title: emptyTitle, onBookRide: () => context.go(Routes.ride));
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: trips.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, i) => TripHistoryCard(trip: trips[i]),
      ),
    );
  }
}

/// One Activity card: date, status pill, vehicle icon, pickup → drop, subtitle and fare.
class TripHistoryCard extends StatelessWidget {
  const TripHistoryCard({super.key, required this.trip});
  final Trip trip;

  static (StatusKind, String) statusOf(Trip trip) => switch (trip.status) {
        TripStatus.completed => (StatusKind.completed, 'Completed'),
        TripStatus.delivered => (StatusKind.delivered, 'Delivered'),
        TripStatus.cancelled => (StatusKind.cancelled, 'Cancelled'),
        _ => (StatusKind.inProgress, 'In progress'),
      };

  static IconData iconOf(Trip trip) => trip.isParcel ? Symbols.package_2_rounded : trip.vehicle.icon;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final (kind, label) = statusOf(trip);
    final cancelled = trip.status == TripStatus.cancelled;
    final subtitle = trip.isParcel
        ? 'Parcel · ${trip.vehicle.label}'
        : cancelled
            ? '${trip.vehicle.label} · No charge'
            : '${trip.vehicle.label}${trip.driver == null ? '' : ' · ${trip.driver!.name}'}';
    return Semantics(
      button: true,
      label: '${trip.fromLabel} to ${trip.toLabel}, ${formatInr(trip.fare)}, $label. Open trip details',
      excludeSemantics: true,
      child: RidoCard(
        onTap: () => context.push(Routes.tripDetails(trip.id)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    formatRelativeDay(trip.startedAt, withTime: true),
                    style: RidoTextStyles.tabular(t.bodySmall.copyWith(color: RidoColors.navy500)),
                  ),
                ),
                StatusPill(kind, label: label),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(color: RidoColors.coral50, borderRadius: RidoRadii.cardRadius),
                  child: Icon(iconOf(trip), color: RidoColors.coral500, fill: 1),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${trip.fromLabel} → ${trip.toLabel}', style: t.bodySemibold, maxLines: 2),
                      Text(subtitle,
                          style: t.bodySmall.copyWith(color: RidoColors.navy500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  formatInr(trip.fare),
                  style: RidoTextStyles.tabular(
                    t.h2.copyWith(color: cancelled ? RidoColors.navy500 : RidoColors.navy900),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
