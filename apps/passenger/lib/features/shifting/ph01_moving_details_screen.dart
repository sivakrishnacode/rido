import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';
import 'package:tamiltaxi_ui/tamiltaxi_ui.dart';

import '../../router/routes.dart';
import '../../state/shifting_flow.dart';
import '../parcel/widgets/parcel_widgets.dart';
import 'widgets/shifting_widgets.dart';

/// PH-01 House shifting · moving details: in town or to another town, the old and new home (each with its floor and
/// lift) and how big the home is (it suggests the vehicle and helpers). Next → PH-02 items.
class PH01MovingDetailsScreen extends ConsumerWidget {
  const PH01MovingDetailsScreen({super.key, this.showcase = false});

  /// Opened on its own from the Design gallery: render the sample plan, start no timers.
  final bool showcase;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.type;
    final s = showcase ? ShiftingFlowState.sample() : ref.watch(shiftingFlowProvider);
    final flow = ref.read(shiftingFlowProvider.notifier);
    final d = s.details;
    final size = GoodsModeRates.sizes[d.homeSize]!;

    Future<void> pick({required bool pickup}) async {
      final p = await showParcelPlacePicker(
        context,
        title: pickup ? 'Moving from' : 'Moving to',
        current: pickup ? s.pickup : s.drop,
        anywhere: !pickup && d.between,
      );
      if (p == null) return;
      pickup ? flow.setPickup(p) : flow.setDrop(p);
    }

    return ShiftingScaffold(
      title: 'House shifting',
      step: 1,
      onBack: () => context.canPop() ? context.pop() : context.go(Routes.parcel),
      bottom: ShiftingPriceBar(
        total: s.placesReady ? s.quote?.lines.total : null,
        caption: s.placesReady ? '${size.helpers} helpers · ${s.vehicleOrSuggested.label} suggested' : 'Choose the new home to see the price',
        label: 'Add items',
        onPressed: showcase ? () {} : (s.placesReady ? () => context.push(Routes.shiftingItems) : null),
      ),
      children: [
        Text('Moving home?', style: t.h1),
        const SizedBox(height: 4),
        Text('A truck, helpers and packing if you want it. You see the full price before you book.',
            style: t.bodySmall.copyWith(color: TtColors.navy500)),
        const SizedBox(height: TtSpacing.l),
        TtSegmented<bool>(
          options: const [false, true],
          labelOf: (between) => between ? 'To another town' : 'In town',
          selected: d.between,
          onChanged: showcase ? (_) {} : flow.setBetween,
        ),
        const SizedBox(height: TtSpacing.l),
        MoveEndCard(
          isPickup: true,
          place: s.pickup,
          floor: d.pickupFloor,
          lift: d.pickupLift,
          onPlace: showcase ? null : () => pick(pickup: true),
          onFloor: (f) => flow.setFloor(pickup: true, floor: f),
          onLift: (v) => flow.setLift(pickup: true, lift: v),
        ),
        MoveEndCard(
          isPickup: false,
          place: s.drop,
          floor: d.dropFloor,
          lift: d.dropLift,
          onPlace: showcase ? null : () => pick(pickup: false),
          onFloor: (f) => flow.setFloor(pickup: false, floor: f),
          onLift: (v) => flow.setLift(pickup: false, lift: v),
        ),
        const SizedBox(height: TtSpacing.s),
        Text('How big is the home?', style: t.bodySemibold),
        const SizedBox(height: 2),
        Text('Sets the vehicle and how many helpers come. You can change the vehicle later.',
            style: t.bodySmall.copyWith(color: TtColors.navy500)),
        const SizedBox(height: TtSpacing.m),
        LayoutBuilder(
          builder: (context, c) {
            final w = (c.maxWidth - TtSpacing.s) / 2;
            return Wrap(
              spacing: TtSpacing.s,
              runSpacing: TtSpacing.s,
              children: [
                for (final hs in HomeSize.values)
                  SizedBox(
                    width: hs == HomeSize.threeBhk ? c.maxWidth : w,
                    child: HomeSizeTile(
                      size: hs,
                      selected: hs == d.homeSize,
                      onTap: showcase ? null : () => flow.setHomeSize(hs),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: TtSpacing.l),
        _Included(size: d.homeSize, vehicle: s.vehicleOrSuggested),
      ],
    );
  }
}

/// "Included for a 1 BHK": the vehicle and helpers that come.
class _Included extends StatelessWidget {
  const _Included({required this.size, required this.vehicle});
  final HomeSize size;
  final VehicleKind vehicle;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final helpers = GoodsModeRates.sizes[size]!.helpers;
    return Container(
      padding: const EdgeInsets.all(TtSpacing.m),
      decoration: const BoxDecoration(color: TtColors.infoTint, borderRadius: TtRadii.cardRadius),
      child: Row(
        children: [
          ParcelVehicleArt(kind: vehicle, width: 72, height: 48, tile: TtColors.surface),
          const SizedBox(width: TtSpacing.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('For a ${size == HomeSize.fewItems ? 'few items' : size.label}', style: t.bodySemibold),
                Text(
                  '${vehicle.label}${vehicle.bedLabel == null ? '' : ' · ${vehicle.bedLabel}'} · $helpers helper${helpers == 1 ? '' : 's'} to load and unload',
                  style: t.bodySmall.copyWith(color: TtColors.navy700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
