import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

import '../../router/routes.dart';
import '../../state/driver_account.dart';
import 'widgets/signup_widgets.dart';

/// D-05 Choose vehicle: the vehicle types for the chosen work type with their monthly plan
/// price and a "1st month free" tag. Pickup / truck show "₹—" and "Contact us". Live API: prices from
/// the API's monthly plans.
class D05ChooseVehicleScreen extends ConsumerStatefulWidget {
  const D05ChooseVehicleScreen({super.key, this.showcase = false});

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  @override
  ConsumerState<D05ChooseVehicleScreen> createState() => _D05ChooseVehicleScreenState();
}

class _D05ChooseVehicleScreenState extends ConsumerState<D05ChooseVehicleScreen> {
  late final SignupDraft _draft = widget.showcase ? const SignupDraft() : ref.read(signupProvider);
  late VehicleKind _selected = _draft.vehicle;

  List<VehicleKind> get _options => _draft.workType == WorkType.rides
      ? const [VehicleKind.bike, VehicleKind.auto, VehicleKind.cab]
      : const [
          VehicleKind.goodsBike,
          VehicleKind.threeWheeler,
          VehicleKind.miniTruck,
          VehicleKind.pickup,
          VehicleKind.truck,
        ];

  int? _price(VehicleKind k) => widget.showcase
      ? Seed.vehicle(k).subscriptionPrice
      : (ref.read(monthlyPlanPricesProvider).value ?? const {})[k] ?? Seed.vehicle(k).subscriptionPrice;

  /// Paid plans on: show monthly prices. Off (the free app): every vehicle is free.
  bool get _plansOn => widget.showcase || ref.read(driverPlansEnabledProvider);

  void _tap(VehicleKind k) {
    if (_plansOn && _price(k) == null) {
      showRidoSnack(context, "We'll call you about pricing");
      return;
    }
    setState(() => _selected = k);
  }

  void _continue() {
    ref.read(signupProvider.notifier).update((d) => d.copyWith(vehicle: _selected));
    context.push(Routes.personalDetails);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    if (!widget.showcase) ref.watch(monthlyPlanPricesProvider);
    final plansOn = widget.showcase || ref.watch(driverPlansEnabledProvider);
    final options = _options;
    final rides = _draft.workType == WorkType.rides;
    final rows = <List<VehicleKind>>[
      for (var i = 0; i < options.length; i += 2) options.sublist(i, (i + 2).clamp(0, options.length)),
    ];
    return Scaffold(
      backgroundColor: RidoColors.surface,
      appBar: SignupAppBar(title: 'Choose your vehicle', step: 2, onBack: backOr(context, Routes.workType)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(RidoSpacing.l, RidoSpacing.xl, RidoSpacing.l, RidoSpacing.l),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(rides ? 'Which vehicle do you drive?' : 'Which goods vehicle do you drive?', style: t.h1),
                  const SizedBox(height: RidoSpacing.xs),
                  Text(
                      plansOn
                          ? '${rides ? 'Rides' : 'Deliveries'} · one flat plan per month, no commission.'
                          : '${rides ? 'Rides' : 'Deliveries'} · free to use: 0% commission, no subscription.',
                      style: t.body.copyWith(color: RidoColors.navy700)),
                  const SizedBox(height: RidoSpacing.l),
                  for (final row in rows) ...[
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = 0; i < row.length; i++) ...[
                            if (i > 0) const SizedBox(width: RidoSpacing.m),
                            Expanded(
                              child: _VehicleCard(
                                kind: row[i],
                                price: _price(row[i]),
                                free: !plansOn,
                                selected: _selected == row[i],
                                onTap: () => _tap(row[i]),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: RidoSpacing.m),
                  ],
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

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({
    required this.kind,
    required this.price,
    required this.free,
    required this.selected,
    required this.onTap,
  });

  final VehicleKind kind;
  final int? price;

  /// The free app: "Free" instead of a monthly price.
  final bool free;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final price = this.price;
    final name = kind == VehicleKind.truck ? 'Truck 14ft / 17ft' : kind.label;
    return Semantics(
      selected: selected,
      button: true,
      label: '$name, ${free ? 'free' : price == null ? 'price on request' : '${formatInr(price)} per month'}',
      excludeSemantics: true,
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
            padding: const EdgeInsets.all(RidoSpacing.m),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Align(alignment: Alignment.centerLeft, child: VehicleArt(kind, size: 56))),
                    Icon(
                      selected ? Symbols.radio_button_checked_rounded : Symbols.radio_button_unchecked_rounded,
                      color: selected ? RidoColors.coral600 : RidoColors.navy500,
                      size: 26,
                    ),
                  ],
                ),
                const SizedBox(height: RidoSpacing.s),
                Text(name, style: t.h2.copyWith(fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: RidoSpacing.xs),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(free ? 'Free' : price == null ? '₹—' : formatInr(price), style: t.otp),
                      if (!free) ...[
                        const SizedBox(width: 4),
                        Text('/ month', style: t.bodySmall.copyWith(color: RidoColors.navy500)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: RidoSpacing.s),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _Tag(label: free ? '0% commission' : '1st month free', bg: RidoColors.successTint, fg: RidoColors.successText),
                    if (!free && price == null) const _Tag(label: 'Contact us', bg: RidoColors.coral50, fg: RidoColors.coral600),
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

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.bg, required this.fg});
  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: RidoRadii.pillRadius),
        child: Text(label, style: context.type.bodySmallMedium.copyWith(color: fg, fontWeight: FontWeight.w600)),
      );
}
