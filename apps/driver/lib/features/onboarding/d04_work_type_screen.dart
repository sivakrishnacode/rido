import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';
import 'package:tamiltaxi_ui/tamiltaxi_ui.dart';

import '../../router/routes.dart';
import '../../state/driver_account.dart';
import 'widgets/signup_widgets.dart';

/// D-04 Choose work type: "Rides: carry passengers" (bikes and scooties also get small parcels, "Parcels too") or
/// "Deliveries: carry goods" (3-wheeler, mini truck, pickup, truck). Step 1 of 3 from the D-07
/// registration page (work type → vehicle → details).
class D04WorkTypeScreen extends ConsumerStatefulWidget {
  const D04WorkTypeScreen({super.key, this.showcase = false});

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  @override
  ConsumerState<D04WorkTypeScreen> createState() => _D04WorkTypeScreenState();
}

class _D04WorkTypeScreenState extends ConsumerState<D04WorkTypeScreen> {
  late WorkType _selected = widget.showcase ? WorkType.rides : ref.read(signupProvider).workType;

  void _continue() {
    ref.read(signupProvider.notifier).setWorkType(_selected);
    context.push(Routes.chooseVehicle);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Scaffold(
      backgroundColor: TtColors.surface,
      appBar: SignupAppBar(title: 'Choose work type', step: 1, onBack: backOr(context, Routes.documents)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(TtSpacing.l, TtSpacing.xl, TtSpacing.l, TtSpacing.l),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('What will you do on Tamil Taxi?', style: t.h1),
                  const SizedBox(height: TtSpacing.xs),
                  Text('You can do one type of work. Contact support to switch later.',
                      style: t.body.copyWith(color: TtColors.navy700)),
                  const SizedBox(height: TtSpacing.l),
                  _WorkCard(
                    title: 'Rides: carry passengers',
                    subtitle: 'Bike, scooty, auto or car. Bikes and scooties carry small parcels too',
                    vehicles: const [
                      VehicleKind.bike,
                      VehicleKind.scooty,
                      VehicleKind.auto,
                      VehicleKind.cab,
                      VehicleKind.sedan,
                      VehicleKind.suv,
                    ],
                    selected: _selected == WorkType.rides,
                    onTap: () => setState(() => _selected = WorkType.rides),
                  ),
                  const SizedBox(height: TtSpacing.l),
                  _WorkCard(
                    title: 'Deliveries: carry goods',
                    subtitle: 'Shop stock, furniture, house moves',
                    // Two-wheelers aren't here: a bike or scooty driver gets parcels as well as rides (Rides above).
                    vehicles: const [
                      VehicleKind.threeWheeler,
                      VehicleKind.miniTruck,
                      VehicleKind.pickup,
                      VehicleKind.truck,
                    ],
                    selected: _selected == WorkType.deliveries,
                    onTap: () => setState(() => _selected = WorkType.deliveries),
                  ),
                ],
              ),
            ),
          ),
          BottomActions(children: [TtButton(label: 'Continue', onPressed: _continue)]),
        ],
      ),
    );
  }
}

class _WorkCard extends StatelessWidget {
  const _WorkCard({
    required this.title,
    required this.subtitle,
    required this.vehicles,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final List<VehicleKind> vehicles;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? TtColors.coral50 : TtColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: TtRadii.cardRadius,
          side: BorderSide(color: selected ? TtColors.coral100 : TtColors.divider, width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(TtSpacing.l),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: t.h2),
                          const SizedBox(height: 2),
                          Text(subtitle, style: t.body.copyWith(color: TtColors.navy700)),
                        ],
                      ),
                    ),
                    Icon(
                      selected ? Symbols.radio_button_checked_rounded : Symbols.radio_button_unchecked_rounded,
                      color: selected ? TtColors.coral600 : TtColors.navy500,
                      size: 28,
                    ),
                  ],
                ),
                const SizedBox(height: TtSpacing.l),
                // Three to a row (the last row keeps the same tile width).
                for (var r = 0; r < vehicles.length; r += 3) ...[
                  if (r > 0) const SizedBox(height: TtSpacing.s),
                  Row(
                    children: [
                      for (var i = r; i < r + 3; i++) ...[
                        if (i > r) const SizedBox(width: TtSpacing.s),
                        Expanded(
                          child: i >= vehicles.length
                              ? const SizedBox.shrink()
                              : Container(
                                  padding: const EdgeInsets.symmetric(vertical: TtSpacing.s),
                                  decoration: BoxDecoration(
                                    color: selected ? TtColors.surface : TtColors.background,
                                    borderRadius: TtRadii.cardRadius,
                                  ),
                                  child: Column(
                                    children: [
                                      VehicleArt(vehicles[i], width: 64, height: 42),
                                      const SizedBox(height: TtSpacing.xs),
                                      Text(vehicles[i] == VehicleKind.truck ? 'Truck' : vehicles[i].label,
                                          style: t.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                                      // The tag line is kept on every tile of the card so the tiles stay one height.
                                      if (vehicles.any((v) => v.isTwoWheeler))
                                        Text(vehicles[i].isTwoWheeler ? '+ Parcels' : '',
                                            style: t.caption.copyWith(color: TtColors.successText, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
