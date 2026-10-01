import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';
import 'package:tamiltaxi_ui/tamiltaxi_ui.dart';

import '../../common/async_view.dart';
import '../../router/routes.dart';
import '../../state/passenger_session.dart';
import '../../state/ride_flow.dart';
import '../ride/widgets/upcoming_trip_card.dart';
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

  /// Trips booked for later are listed under Upcoming, not in the history.
  List<Trip> _filter(List<Trip> trips, int tab) {
    final past = trips.where((t) => t.status != TripStatus.scheduled);
    return switch (tab) {
      1 => past.where((t) => !t.isParcel).toList(),
      2 => past.where((t) => t.isParcel).toList(),
      _ => past.toList(),
    };
  }

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
                      // Rentals and outstation trips booked for later (rides only).
                      showUpcoming: i != 2,
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

class _TripList extends ConsumerWidget {
  const _TripList({required this.trips, required this.emptyTitle, required this.onRefresh, this.showUpcoming = false});

  final List<Trip> trips;
  final String emptyTitle;
  final Future<void> Function() onRefresh;
  final bool showUpcoming;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upcoming = showUpcoming ? (ref.watch(upcomingTripsProvider).value ?? const <Trip>[]) : const <Trip>[];
    if (trips.isEmpty && upcoming.isEmpty) {
      return S06EmptyActivityView(title: emptyTitle, onBookRide: () => context.go(Routes.ride));
    }
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(upcomingTripsProvider);
        await onRefresh();
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          if (upcoming.isNotEmpty) ...[
            const UpcomingTripsSection(),
            if (trips.isNotEmpty) Text('PAST', style: context.type.overline),
            const SizedBox(height: 8),
          ],
          for (var i = 0; i < trips.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            TripHistoryCard(trip: trips[i]),
          ],
        ],
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
      child: TtCard(
        onTap: () => context.push(Routes.tripDetails(trip.id)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    formatRelativeDay(trip.startedAt, withTime: true),
                    style: TtTextStyles.tabular(t.bodySmall.copyWith(color: TtColors.navy500)),
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
                  decoration: const BoxDecoration(color: TtColors.coral50, borderRadius: TtRadii.cardRadius),
                  child: Icon(iconOf(trip), color: TtColors.coral500, fill: 1),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${trip.fromLabel} → ${trip.toLabel}', style: t.bodySemibold, maxLines: 2),
                      Text(subtitle,
                          style: t.bodySmall.copyWith(color: TtColors.navy500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  formatInr(trip.fare),
                  style: TtTextStyles.tabular(
                    t.h2.copyWith(color: cancelled ? TtColors.navy500 : TtColors.navy900),
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
