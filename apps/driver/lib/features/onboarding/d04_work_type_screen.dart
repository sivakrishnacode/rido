import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

import '../../router/routes.dart';
import '../../state/driver_account.dart';
import 'widgets/signup_widgets.dart';

/// D-04 Choose work type: "Rides: carry passengers" or "Deliveries: carry goods".
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
      backgroundColor: RidoColors.surface,
      appBar: SignupAppBar(title: 'Choose work type', step: 1, onBack: backOr(context, Routes.welcome)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(RidoSpacing.l, RidoSpacing.xl, RidoSpacing.l, RidoSpacing.l),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('What will you do on Rido?', style: t.h1),
                  const SizedBox(height: RidoSpacing.xs),
                  Text('You can do one type of work. Contact support to switch later.',
                      style: t.body.copyWith(color: RidoColors.navy700)),
                  const SizedBox(height: RidoSpacing.l),
                  _WorkCard(
                    title: 'Rides: carry passengers',
                    subtitle: 'Bike taxi, auto or cab',
                    vehicles: const [VehicleKind.bike, VehicleKind.auto, VehicleKind.cab],
                    selected: _selected == WorkType.rides,
                    onTap: () => setState(() => _selected = WorkType.rides),
                  ),
                  const SizedBox(height: RidoSpacing.l),
                  _WorkCard(
                    title: 'Deliveries: carry goods',
                    subtitle: 'Parcels, shop stock, house moves',
                    vehicles: const [VehicleKind.goodsBike, VehicleKind.threeWheeler, VehicleKind.truck],
                    selected: _selected == WorkType.deliveries,
                    onTap: () => setState(() => _selected = WorkType.deliveries),
                  ),
                ],
              ),
            ),
          ),
          BottomActions(children: [RidoButton(label: 'Continue', onPressed: _continue)]),
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
        color: selected ? RidoColors.coral50 : RidoColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: RidoRadii.cardRadius,
          side: BorderSide(color: selected ? RidoColors.coral100 : RidoColors.divider, width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(RidoSpacing.l),
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
                          Text(subtitle, style: t.body.copyWith(color: RidoColors.navy700)),
                        ],
                      ),
                    ),
                    Icon(
                      selected ? Symbols.radio_button_checked_rounded : Symbols.radio_button_unchecked_rounded,
                      color: selected ? RidoColors.coral600 : RidoColors.navy500,
                      size: 28,
                    ),
                  ],
                ),
                const SizedBox(height: RidoSpacing.l),
                Row(
                  children: [
                    for (var i = 0; i < vehicles.length; i++) ...[
                      if (i > 0) const SizedBox(width: RidoSpacing.s),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: RidoSpacing.m),
                          decoration: BoxDecoration(
                            color: selected ? RidoColors.surface : RidoColors.background,
                            borderRadius: RidoRadii.cardRadius,
                          ),
                          child: Column(
                            children: [
                              VehicleArt(vehicles[i], size: 40),
                              const SizedBox(height: RidoSpacing.xs),
                              Text(vehicles[i] == VehicleKind.truck ? 'Truck' : vehicles[i].label,
                                  style: t.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
