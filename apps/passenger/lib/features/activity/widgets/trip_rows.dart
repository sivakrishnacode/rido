import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';
import 'package:tamiltaxi_ui/tamiltaxi_ui.dart';

import '../../../router/routes.dart';

/// A trip's status for lists and details: the pill / text kind and its word.
(StatusKind, String) tripStatusOf(Trip trip) => switch (trip.status) {
  TripStatus.completed => (StatusKind.completed, 'Completed'),
  TripStatus.delivered => (StatusKind.delivered, 'Delivered'),
  TripStatus.cancelled => (StatusKind.cancelled, 'Cancelled'),
  TripStatus.scheduled => (
    StatusKind.inProgress,
    'Scheduled · ${formatWhen(trip.scheduledAt ?? trip.startedAt)}',
  ),
  _ => (StatusKind.inProgress, 'In progress'),
};

/// One past trip in a list, two lines (~60 dp, so a phone shows ten or more): the icon, where it went (the pickup is
/// usually "Current location"; P-22 has both), when and with what, and on the right the fare with its status under
/// it. Tap: trip details (P-22).
class TripHistoryRow extends StatelessWidget {
  const TripHistoryRow({super.key, required this.trip, this.timeOnly = false});
  final Trip trip;

  /// Under a day header: the time alone ("10:23 AM"), not the date.
  final bool timeOnly;

  static IconData iconOf(Trip trip) =>
      trip.isShifting ? Symbols.home_rounded : (trip.isParcel ? Symbols.package_2_rounded : trip.vehicle.icon);

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final (kind, label) = tripStatusOf(trip);
    final cancelled = trip.status == TripStatus.cancelled;
    final what = trip.isShifting
        ? 'Packers & Movers'
        : trip.isParcel
            ? 'Parcel · ${trip.vehicle.label}'
            : '${trip.vehicle.label}${!cancelled && trip.driver != null ? ' · ${trip.driver!.firstName}' : ''}';
    final statusColor = switch (kind) {
      StatusKind.completed || StatusKind.delivered => TtColors.successText,
      StatusKind.cancelled => TtColors.error,
      _ => TtColors.coral600,
    };
    return Semantics(
      button: true,
      label: '${trip.fromLabel} to ${trip.toLabel}, ${formatRelativeDay(trip.startedAt, withTime: true)}, '
          '${formatInr(trip.fare)}, $label. Open trip details',
      excludeSemantics: true,
      child: InkWell(
        onTap: () => context.push(Routes.tripDetails(trip.id)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(color: TtColors.coral50, borderRadius: BorderRadius.all(Radius.circular(10))),
                child: Icon(iconOf(trip), color: TtColors.coral500, fill: 1, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(trip.toLabel,
                        style: t.bodyMedium.copyWith(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(
                      '${timeOnly ? formatTime(trip.startedAt) : formatRelativeDay(trip.startedAt, withTime: true)} · $what',
                      style: TtTextStyles.tabular(t.bodySmall.copyWith(color: TtColors.navy500)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatInr(trip.fare),
                    style: TtTextStyles.tabular(t.bodySemibold.copyWith(color: cancelled ? TtColors.navy500 : TtColors.navy900)),
                  ),
                  const SizedBox(height: 2),
                  Text(label, style: t.caption.copyWith(color: statusColor, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Today", "Yesterday", "30 Sep" (and the year when it isn't this one): a day header in a trip list.
String tripDayLabel(DateTime d, {DateTime? now}) {
  final today = now == null ? TtClock.today : DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  return d.year == today.year ? formatShortDate(d) : formatDate(d);
}

/// Each trip in its own compact card (8 dp apart). [byDay]: under day headers ("Today", "Yesterday", "30 Sep"),
/// the cards then showing the time alone.
class TripRowsGroup extends StatelessWidget {
  const TripRowsGroup({super.key, required this.trips, this.byDay = false});
  final List<Trip> trips;
  final bool byDay;

  Widget _card(Trip trip) => Material(
        color: TtColors.surface,
        shape: RoundedRectangleBorder(borderRadius: TtRadii.cardRadius, side: const BorderSide(color: TtColors.divider)),
        clipBehavior: Clip.antiAlias,
        child: TripHistoryRow(trip: trip, timeOnly: byDay),
      );

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final children = <Widget>[];
    String? day;
    for (final trip in trips) {
      final label = byDay ? tripDayLabel(trip.startedAt) : null;
      if (label != null && label != day) {
        day = label;
        children.add(Padding(
          padding: EdgeInsets.fromLTRB(4, children.isEmpty ? 0 : 12, 4, 6),
          child: Semantics(header: true, child: Text(label, style: t.bodySmallMedium.copyWith(color: TtColors.navy700, fontWeight: FontWeight.w600))),
        ));
      } else if (children.isNotEmpty) {
        children.add(const SizedBox(height: 8));
      }
      children.add(_card(trip));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }
}
