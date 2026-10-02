import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';
import 'package:tamiltaxi_ui/tamiltaxi_ui.dart';

import '../../common/async_view.dart';
import '../../common/trip_routes.dart';
import '../../router/routes.dart';
import '../../state/parcel_flow.dart';
import '../../state/passenger_session.dart';
import '../activity/widgets/trip_rows.dart';
import 'widgets/parcel_widgets.dart';

/// PP-01 Parcel home: in town or to another town, pickup / drop, Packers & Movers, goods vehicle grid, recent parcels.
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
      backgroundColor: TtColors.background,
      body: Column(
        children: [
          // The status bar keeps a white strip: the page scrolls under it, not under the clock.
          Container(color: TtColors.surface, height: MediaQuery.paddingOf(context).top),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    color: TtColors.surface,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Send anything', style: t.h1),
                        const SizedBox(height: 2),
                        Text(
                          flow.outstation ? 'To another town, by the km, one way' : 'Anywhere in town, in minutes',
                          style: t.bodySmall.copyWith(color: TtColors.navy500),
                        ),
                        const SizedBox(height: 12),
                        TtSegmented<bool>(
                          options: const [false, true],
                          labelOf: (out) => out ? 'To another town' : 'In town',
                          selected: flow.outstation,
                          onChanged: showcase ? (_) {} : ctrl.setOutstation,
                        ),
                        const SizedBox(height: 16),
                        if (flow.isActive && !showcase) ...[
                          TtBanner(
                            type: TtBannerType.info,
                            icon: Symbols.local_shipping_rounded,
                            title: 'Parcel in progress',
                            message: _activeMessage(flow),
                            onTap: () {
                              final r = routeForParcelPhase(flow.phase);
                              if (r != null) context.go(r);
                            },
                          ),
                          const SizedBox(height: 12),
                        ],
                        _RouteCard(
                          flow: flow,
                          onPickup: () => context.push(Routes.parcelPickup),
                          onDrop: () => openParcelDrop(context, ref),
                        ),
                      ],
                    ),
                  ),
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: _ShiftingCard(onTap: () => context.push(Routes.shifting)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SectionLabel('Choose a vehicle', padding: EdgeInsets.fromLTRB(0, 20, 0, 10)),
                        _VehicleGrid(
                          // Another town: goods trucks only.
                          vehicles: flow.outstation
                              ? [for (final k in GoodsModeRates.goodsTrucks) Seed.vehicle(k)]
                              : Seed.goodsVehicles,
                          onTap: (kind) {
                            ctrl.selectVehicle(kind);
                            context.push(Routes.parcelPickup);
                          },
                        ),
                        const SizedBox(height: 12),
                        const _ZeroCommissionStrip(),
                        const SectionLabel('Recent', padding: EdgeInsets.fromLTRB(0, 20, 0, 10)),
                        AsyncView<List<Trip>>(
                          value: recent,
                          onRetry: () => ref.invalidate(recentParcelsProvider),
                          loading: const _RecentSkeleton(),
                          data: (trips) => trips.isEmpty
                              ? Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: Row(
                                    children: [
                                      const Icon(Symbols.deployed_code_rounded, color: TtColors.navy500),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          'No parcels yet. Your deliveries will show up here.',
                                          style: t.bodySmall.copyWith(color: TtColors.navy500),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : TripRowsGroup(trips: trips.take(3).toList()),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
    }) => Semantics(
      button: true,
      label: semantics,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 9, 8, 9),
          child: Row(
            children: [
              SizedBox(width: 24, child: Center(child: marker)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: t.caption.copyWith(color: TtColors.navy500)),
                    Text(
                      value,
                      style: t.bodyMedium.copyWith(color: valueColor, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Symbols.chevron_right_rounded, color: chevron ? TtColors.navy700 : TtColors.navy300, size: 20),
            ],
          ),
        ),
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: TtColors.surface,
        borderRadius: TtRadii.cardRadius,
        border: Border.all(color: TtColors.divider),
        boxShadow: TtShadows.soft,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          row(
            marker: const PickupDot(size: 10),
            label: 'Pickup from',
            value: shortAddress(flow.pickup),
            valueColor: TtColors.navy900,
            onTap: onPickup,
            semantics: 'Pickup from ${flow.pickup.name}. Edit pickup details',
          ),
          const Divider(height: 1, indent: 46, endIndent: 12),
          row(
            marker: const DropPin(size: 20),
            label: 'Deliver to',
            value: flow.dropSet ? shortAddress(flow.drop) : 'Tap to add drop',
            valueColor: flow.dropSet ? TtColors.navy900 : TtColors.coral600,
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
  const _VehicleGrid({required this.vehicles, required this.onTap});
  final List<VehicleType> vehicles;
  final ValueChanged<VehicleKind> onTap;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < vehicles.length; i += 2) {
      final a = vehicles[i];
      final b = i + 1 < vehicles.length ? vehicles[i + 1] : null;
      rows.add(
        Padding(
          padding: EdgeInsets.only(bottom: i + 2 < vehicles.length ? 8 : 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _VehicleTile(vehicle: a, onTap: () => onTap(a.kind)),
              ),
              if (b != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: _VehicleTile(vehicle: b, onTap: () => onTap(b.kind)),
                ),
              ],
            ],
          ),
        ),
      );
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
    return TtCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: Semantics(
        button: true,
        label: '${vehicle.name}, ${vehicle.capacityLabel}',
        excludeSemantics: true,
        child: Row(
          children: [
            ParcelVehicleArt(kind: vehicle.kind, width: 50, height: 38),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // One line ("Truck 14ft / 17ft" shrinks a little), so the tiles in a row stay the same height.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(vehicle.name, style: t.bodySemibold, maxLines: 1),
                  ),
                  Text(vehicle.capacityLabel, style: t.bodySmall.copyWith(color: TtColors.navy500)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Packers & Movers: opens the moving flow (PH-01).
class _ShiftingCard extends StatelessWidget {
  const _ShiftingCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Semantics(
      button: true,
      label: 'Packers and Movers. A truck, helpers and packing on the day you choose',
      excludeSemantics: true,
      child: Material(
        color: TtColors.navy900,
        borderRadius: TtRadii.cardRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'Packers & Movers',
                              style: t.bodySemibold.copyWith(color: Colors.white, fontSize: 17),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: const BoxDecoration(color: TtColors.coral600, borderRadius: TtRadii.pillRadius),
                            child: Text(
                              'NEW',
                              style: t.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Shift your home: a truck, helpers and packing, price up front',
                        style: t.bodySmall.copyWith(color: Colors.white70),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const ParcelVehicleArt(kind: VehicleKind.miniTruck, width: 76, height: 50, tile: TtColors.navy700),
                const Icon(Symbols.chevron_right_rounded, color: Colors.white70),
              ],
            ),
          ),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(color: TtColors.coral50, borderRadius: TtRadii.cardRadius),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: const BoxDecoration(color: TtColors.surface, borderRadius: TtRadii.pillRadius),
            child: Text(
              '0%',
              style: t.bodySmallMedium.copyWith(color: TtColors.coral600, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text('Your driver keeps 100% of the fare', style: t.bodyMedium)),
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
            children: [SkeletonBox(width: 180, height: 14), SizedBox(height: 8), SkeletonBox(width: 120, height: 12)],
          ),
        ),
      ],
    ),
  );
}
