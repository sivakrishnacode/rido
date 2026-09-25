import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

import '../../common/async_view.dart';
import '../../common/trip_routes.dart';
import '../../router/routes.dart';
import '../../state/parcel_flow.dart';
import '../../state/passenger_session.dart';
import 'widgets/parcel_widgets.dart';

/// PP-01 Parcel home: pickup / drop cards, goods vehicle grid, recent parcels.
class PP01ParcelHomeScreen extends ConsumerWidget {
  const PP01ParcelHomeScreen({super.key, this.showcase = false});

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.type;
    final flow = ref.watch(parcelFlowProvider);
    final ctrl = ref.read(parcelFlowProvider.notifier);
    final recent = ref.watch(recentParcelsProvider);

    return Scaffold(
      backgroundColor: RidoColors.background,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: RidoColors.surface,
              padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top + 20, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Send anything, anywhere in Coimbatore', style: t.display),
                  const SizedBox(height: 20),
                  if (flow.isActive && !showcase) ...[
                    RidoBanner(
                      type: RidoBannerType.info,
                      icon: Symbols.local_shipping_rounded,
                      title: 'Parcel in progress',
                      message: _activeMessage(flow),
                      onTap: () {
                        final r = routeForParcelPhase(flow.phase);
                        if (r != null) context.go(r);
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                  _RouteCard(
                    flow: flow,
                    onPickup: () => context.push(Routes.parcelPickup),
                    onDrop: () => context.push(Routes.parcelDrop),
                  ),
                ],
              ),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SectionLabel('Choose a vehicle', padding: EdgeInsets.fromLTRB(0, 24, 0, 12)),
                  _VehicleGrid(
                    onTap: (kind) {
                      ctrl.selectVehicle(kind);
                      context.push(Routes.parcelPickup);
                    },
                  ),
                  const SizedBox(height: 16),
                  const _ZeroCommissionStrip(),
                  const SectionLabel('Recent', padding: EdgeInsets.fromLTRB(0, 24, 0, 12)),
                  AsyncView<List<Trip>>(
                    value: recent,
                    onRetry: () => ref.invalidate(recentParcelsProvider),
                    loading: const _RecentSkeleton(),
                    data: (trips) => trips.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                const Icon(Symbols.deployed_code_rounded, color: RidoColors.navy500),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text('No parcels yet. Your deliveries will show up here.',
                                      style: t.bodySmall.copyWith(color: RidoColors.navy500)),
                                ),
                              ],
                            ),
                          )
                        : Column(
                            children: [
                              for (final trip in trips.take(3))
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: _RecentParcelTile(
                                    trip: trip,
                                    onTap: () => context.go(Routes.tripDetails(trip.id)),
                                  ),
                                ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _activeMessage(ParcelFlowState f) {
    final name = f.driver.firstName;
    final receiver = f.details.receiverName.split(' ').first;
    return switch (f.phase) {
      ParcelPhase.searching => 'Finding a nearby ${f.vehicle.label}…',
      ParcelPhase.assigned => '$name is coming to pick up',
      ParcelPhase.atPickup => '$name is at the pickup',
      ParcelPhase.inTransit => 'On the way to $receiver',
      ParcelPhase.delivered => 'Delivered to $receiver. Tap to rate $name',
      _ => 'Tap to open',
    };
  }
}

class _RouteCard extends StatelessWidget {
  const _RouteCard({required this.flow, required this.onPickup, required this.onDrop});

  final ParcelFlowState flow;
  final VoidCallback onPickup;
  final VoidCallback onDrop;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    Widget row({
      required Widget marker,
      required String label,
      required String value,
      required Color valueColor,
      required VoidCallback onTap,
      bool chevron = false,
      String semantics = '',
    }) =>
        Semantics(
          button: true,
          label: semantics,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: Row(
                children: [
                  SizedBox(width: 32, child: Center(child: marker)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label, style: t.bodySmall.copyWith(color: RidoColors.navy500)),
                        const SizedBox(height: 2),
                        Text(value,
                            style: t.bodyMedium.copyWith(fontSize: 17, color: valueColor, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  if (chevron) const Icon(Symbols.chevron_right_rounded, color: RidoColors.navy700),
                ],
              ),
            ),
          ),
        );

    return Container(
      decoration: BoxDecoration(
        color: RidoColors.surface,
        borderRadius: RidoRadii.cardRadius,
        border: Border.all(color: RidoColors.divider),
        boxShadow: RidoShadows.soft,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          row(
            marker: const PickupDot(size: 12),
            label: 'Pickup from',
            value: shortAddress(flow.pickup),
            valueColor: RidoColors.navy900,
            onTap: onPickup,
            semantics: 'Pickup from ${flow.pickup.name}. Edit pickup details',
          ),
          const Divider(indent: 60, endIndent: 16),
          row(
            marker: const DropPin(size: 26),
            label: 'Deliver to',
            value: flow.dropSet ? shortAddress(flow.drop) : 'Tap to add drop',
            valueColor: flow.dropSet ? RidoColors.navy900 : RidoColors.coral600,
            onTap: onDrop,
            chevron: true,
            semantics: flow.dropSet ? 'Deliver to ${flow.drop.name}. Edit drop details' : 'Add a drop address',
          ),
        ],
      ),
    );
  }
}

class _VehicleGrid extends StatelessWidget {
  const _VehicleGrid({required this.onTap});
  final ValueChanged<VehicleKind> onTap;

  @override
  Widget build(BuildContext context) {
    const vehicles = Seed.goodsVehicles;
    final rows = <Widget>[];
    for (var i = 0; i < vehicles.length; i += 2) {
      final a = vehicles[i];
      final b = i + 1 < vehicles.length ? vehicles[i + 1] : null;
      rows.add(Padding(
        padding: EdgeInsets.only(bottom: i + 2 < vehicles.length ? 12 : 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _VehicleTile(vehicle: a, onTap: () => onTap(a.kind))),
            if (b != null) ...[
              const SizedBox(width: 12),
              Expanded(child: _VehicleTile(vehicle: b, onTap: () => onTap(b.kind))),
            ],
          ],
        ),
      ));
    }
    return Column(children: rows);
  }
}

class _VehicleTile extends StatelessWidget {
  const _VehicleTile({required this.vehicle, required this.onTap});
  final VehicleType vehicle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return RidoCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 14),
      child: Semantics(
        button: true,
        label: '${vehicle.name}, ${vehicle.capacityLabel}',
        excludeSemantics: true,
        child: Row(
          children: [
            ParcelVehicleArt(kind: vehicle.kind, width: 52, height: 44),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(vehicle.name, style: t.bodySemibold, maxLines: 2, overflow: TextOverflow.ellipsis),
                  Text(vehicle.capacityLabel, style: t.bodySmall.copyWith(color: RidoColors.navy500)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ZeroCommissionStrip extends StatelessWidget {
  const _ZeroCommissionStrip();

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: const BoxDecoration(color: RidoColors.coral50, borderRadius: RidoRadii.cardRadius),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: const BoxDecoration(color: RidoColors.surface, borderRadius: RidoRadii.pillRadius),
            child: Text('0%', style: t.bodySmallMedium.copyWith(color: RidoColors.coral600, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text('Your driver keeps 100% of the fare', style: t.bodyMedium)),
        ],
      ),
    );
  }
}

class _RecentParcelTile extends StatelessWidget {
  const _RecentParcelTile({required this.trip, required this.onTap});
  final Trip trip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final status = switch (trip.status) {
      TripStatus.delivered => StatusKind.delivered,
      TripStatus.cancelled => StatusKind.cancelled,
      TripStatus.completed => StatusKind.completed,
      _ => StatusKind.inProgress,
    };
    return RidoCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(color: RidoColors.coral50, borderRadius: RidoRadii.cardRadius),
            child: const Icon(Symbols.deployed_code_rounded, fill: 1, color: RidoColors.coral500),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${trip.fromLabel} → ${trip.toLabel}',
                    style: t.bodyMedium.copyWith(fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
                Text(
                  '${formatRelativeDay(trip.startedAt)} · ${trip.vehicle.label} · ${formatInr(trip.fare)}',
                  style: RidoTextStyles.tabular(t.bodySmall.copyWith(color: RidoColors.navy500)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          StatusPill(status),
        ],
      ),
    );
  }
}

class _RecentSkeleton extends StatelessWidget {
  const _RecentSkeleton();

  @override
  Widget build(BuildContext context) => const SkeletonShimmer(
        child: Row(
          children: [
            SkeletonBox(width: 40, height: 40, radius: 12),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: 180, height: 14),
                  SizedBox(height: 8),
                  SkeletonBox(width: 120, height: 12),
                ],
              ),
            ),
          ],
        ),
      );
}
