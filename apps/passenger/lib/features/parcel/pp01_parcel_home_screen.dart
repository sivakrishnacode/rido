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
import 'pp05_prohibited_items_sheet.dart';
import 'widgets/parcel_widgets.dart';

/// PP-01 Parcel home: in town or to another town, the pickup (your location, you as the sender) and the drop with a
/// Switch, Packers & Movers, goods vehicle shortcuts, recent parcels. Booking starts from the drop: search → PP-03
/// drop details → PP-06 choose vehicle and book.
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
    final me = ref.watch(currentProfileProvider);
    final d = flow.details;
    // Who the driver calls at the pickup: the sender typed on PP-02, else the rider (as booked).
    final senderName = d.senderName.trim().isNotEmpty ? d.senderName : (me.name == kPlaceholderName ? '' : me.name);
    final senderPhone = d.senderName.trim().isNotEmpty ? d.senderPhone : me.phone;

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
                          sender: senderName.isEmpty ? null : '$senderName · ${localPhone(senderPhone)}',
                          onPickup: () => context.push(Routes.parcelPickup),
                          onDrop: () => openParcelDrop(context, ref),
                          // A parcel coming to you (in town only: the pickup must be in the service area).
                          onSwitch: flow.outstation ? null : () => showcase ? null : _switch(context, ref),
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
                          // A shortcut: the vehicle is chosen, then the drop (PP-06 still offers the others).
                          onTap: (kind) {
                            ctrl.selectVehicle(kind);
                            openParcelDrop(context, ref);
                          },
                        ),
                        const SizedBox(height: 12),
                        const _ProhibitedItemsStrip(),
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

  /// Switch: pickup and drop change places. With no drop yet, asks where the parcel comes from; your location
  /// becomes the drop.
  static Future<void> _switch(BuildContext context, WidgetRef ref) async {
    final s = ref.read(parcelFlowProvider);
    final ctrl = ref.read(parcelFlowProvider.notifier);
    if (s.pickup.isUnknownPickup) return showTtSnack(context, 'Finding your location…');
    if (!s.dropSet) {
      final p = await showParcelPlacePicker(context, title: 'Pick up from');
      if (p == null || !context.mounted) return;
      ctrl.setDrop(p);
    }
    ctrl.swapStops();
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
  const _RouteCard({required this.flow, required this.sender, required this.onPickup, required this.onDrop, this.onSwitch});

  final ParcelFlowState flow;

  /// "Priya Raman · 98765 43210" under the pickup (null: no name yet).
  final String? sender;
  final VoidCallback onPickup;
  final VoidCallback onDrop;

  /// Null hides the Switch button.
  final VoidCallback? onSwitch;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    // Room on the right for the Switch button.
    final right = onSwitch == null ? 12.0 : 60.0;
    Widget row({
      required Widget marker,
      required String label,
      required String value,
      required Color valueColor,
      required VoidCallback onTap,
      String? note,
      String semantics = '',
    }) => Semantics(
      button: true,
      label: semantics,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.fromLTRB(12, 10, right, 10),
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
                    if (note != null)
                      Text(
                        note,
                        style: TtTextStyles.tabular(t.bodySmall.copyWith(color: TtColors.navy500)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (onSwitch == null) const Icon(Symbols.chevron_right_rounded, color: TtColors.navy300, size: 20),
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
      child: Stack(
        children: [
          Column(
            children: [
              row(
                marker: const PickupDot(size: 10),
                label: 'Pickup from',
                value: shortAddress(flow.pickup),
                valueColor: TtColors.navy900,
                note: sender,
                onTap: onPickup,
                semantics: 'Pickup from ${flow.pickup.name}${sender == null ? '' : ', sender $sender'}. Edit pickup details',
              ),
              const Divider(height: 1, indent: 46, endIndent: 12),
              row(
                marker: const DropPin(size: 20),
                label: 'Deliver to',
                value: flow.dropSet ? shortAddress(flow.drop) : 'Where should it go?',
                valueColor: flow.dropSet ? TtColors.navy900 : TtColors.coral600,
                onTap: onDrop,
                semantics: flow.dropSet ? 'Deliver to ${flow.drop.name}. Edit drop details' : 'Add a drop address',
              ),
            ],
          ),
          if (onSwitch != null)
            Positioned(
              right: 10,
              top: 0,
              bottom: 0,
              child: Center(
                child: Tooltip(
                  message: 'Switch pickup and drop',
                  child: Material(
                    color: TtColors.surface,
                    shape: const CircleBorder(side: BorderSide(color: TtColors.divider)),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: onSwitch,
                      child: const SizedBox(
                        width: 40,
                        height: 40,
                        child: Icon(Symbols.swap_vert_rounded, color: TtColors.navy900, size: 22),
                      ),
                    ),
                  ),
                ),
              ),
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

/// "What can't I send?" strip: opens the prohibited-items list (PP-05) before the customer books.
class _ProhibitedItemsStrip extends StatelessWidget {
  const _ProhibitedItemsStrip();

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Material(
      color: TtColors.coral50,
      borderRadius: TtRadii.cardRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => PP05ProhibitedItemsSheet.show(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              const Icon(Symbols.block_rounded, color: TtColors.coral600, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text("What can't I send?", style: t.bodyMedium)),
              Text('See list', style: t.bodySmallMedium.copyWith(color: TtColors.coral600)),
              const Icon(Symbols.chevron_right_rounded, color: TtColors.coral600, size: 20),
            ],
          ),
        ),
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
