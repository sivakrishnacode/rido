import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';
import 'package:tamiltaxi_ui/tamiltaxi_ui.dart';

import '../../../state/ride_flow.dart';
import '../../../state/shifting_flow.dart' show slotLabel;

/// What a trip booked for later is: "Rental · 4 hrs · 40 km", "Outstation · round trip", "House shifting · 1 BHK",
/// "Goods · another town".
String modeLabelOf(Trip trip) {
  if (trip.shifting case final s?) return 'House shifting · ${s.homeSize.label}';
  if (trip.isParcel) return trip.rideMode == RideMode.outstation ? 'Goods · another town' : 'Parcel';
  return rideModeLabel(trip.rideMode, trip.modeTerms) ?? 'Ride';
}

/// When a booking is for: "Tomorrow, 6:00 AM"; a house shift's slot "Sat 3 Oct, 9–11 AM".
String whenLabelOf(Trip trip) {
  final at = trip.scheduledAt;
  if (at == null) return 'Booked for later';
  if (!trip.isShifting) return formatWhen(at);
  return '${formatWhen(at).split(', ').first}, ${slotLabel(at.hour)}';
}

/// A trip booked for later: picture, when, what, from → to, fare and (with [onCancel]) a free Cancel.
class UpcomingTripCard extends StatelessWidget {
  const UpcomingTripCard({super.key, required this.trip, this.onCancel, this.onTap, this.compact = false, this.showWhen = true});

  final Trip trip;
  final VoidCallback? onCancel;
  final VoidCallback? onTap;

  /// Home: one line of route, no Cancel button (the card opens the details).
  final bool compact;

  /// False where the screen already says when (P-36): no date pill, no "30 min before" note.
  final bool showWhen;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Material(
      color: TtColors.surface,
      borderRadius: TtRadii.cardRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(borderRadius: TtRadii.cardRadius, border: Border.all(color: TtColors.divider)),
          padding: const EdgeInsets.all(TtSpacing.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  if (showWhen)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: const BoxDecoration(color: TtColors.coral50, borderRadius: TtRadii.pillRadius),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Symbols.event_rounded, size: 16, color: TtColors.coral600, fill: 1),
                      const SizedBox(width: 4),
                      Text(whenLabelOf(trip),
                          style: t.bodySmallMedium.copyWith(color: TtColors.coral600, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                  if (!showWhen) Text('Your booking', style: t.bodySmallMedium.copyWith(color: TtColors.navy500)),
                  const Spacer(),
                  Text(formatInr(trip.fare), style: TtTextStyles.tabular(t.bodySemibold)),
                ],
              ),
              const SizedBox(height: TtSpacing.m),
              Row(
                children: [
                  VehicleArt(trip.vehicle, width: 64, height: 42),
                  const SizedBox(width: TtSpacing.m),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${trip.vehicle.label} · ${modeLabelOf(trip)}', style: t.bodySemibold, maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text(
                          trip.rideMode == RideMode.rental ? 'From ${trip.pickup.name}' : '${trip.pickup.name} → ${trip.drop.name}',
                          style: t.bodySmall.copyWith(color: TtColors.navy500),
                          maxLines: compact ? 1 : 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (compact) const Icon(Symbols.chevron_right_rounded, color: TtColors.navy500),
                ],
              ),
              if (!compact && showWhen) ...[
                const SizedBox(height: TtSpacing.m),
                Text("We'll start finding your ${trip.isShifting ? 'movers' : 'driver'} 30 min before. Free to cancel until then.",
                    style: t.caption.copyWith(color: TtColors.navy500)),
                if (onCancel != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: onCancel,
                      icon: const Icon(Symbols.event_busy_rounded, size: 18),
                      label: const Text('Cancel booking'),
                      style: TextButton.styleFrom(foregroundColor: TtColors.error, minimumSize: const Size(48, 48)),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Asks, then cancels a trip booked for later; tells the rider how it went.
Future<void> confirmCancelUpcoming(BuildContext context, WidgetRef ref, Trip trip) async {
  final ok = await showTtConfirm(
    context,
    title: 'Cancel this booking?',
    message: '${modeLabelOf(trip)}${trip.scheduledAt == null ? '' : ', ${whenLabelOf(trip)}'}. Nothing is charged.',
    confirmLabel: 'Cancel booking',
    cancelLabel: 'Keep it',
    destructive: true,
    icon: Symbols.event_busy_rounded,
  );
  if (!ok || !context.mounted) return;
  final error = await ref.read(rideFlowProvider.notifier).cancelUpcoming(trip.id);
  if (!context.mounted) return;
  showTtSnack(context, error ?? 'Booking cancelled', success: error == null);
}

/// Every upcoming trip with Cancel (Activity); nothing when there are none.
class UpcomingTripsSection extends ConsumerWidget {
  const UpcomingTripsSection({super.key, this.showcase = false});
  final bool showcase;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.type;
    final trips = showcase ? const <Trip>[] : (ref.watch(upcomingTripsProvider).value ?? const <Trip>[]);
    if (trips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: TtSpacing.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('UPCOMING', style: t.overline),
          const SizedBox(height: TtSpacing.s),
          for (final trip in trips) ...[
            UpcomingTripCard(trip: trip, onCancel: () => confirmCancelUpcoming(context, ref, trip)),
            const SizedBox(height: TtSpacing.m),
          ],
        ],
      ),
    );
  }
}
