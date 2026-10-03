import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';
import 'package:tamiltaxi_ui/tamiltaxi_ui.dart';

import '../../common/showcase.dart';
import '../../router/routes.dart';
import '../../state/driver_account.dart';
import 'widgets/signup_widgets.dart';

/// D-05 Choose vehicle: the vehicle types for the chosen work type with what each carries (passengers, or the load
/// in kg / tonnes). Paid plans on: also the monthly plan price and a "1st month free" tag; pickup / truck show "₹—"
/// and "Contact us". Live API: prices from the API's monthly plans.
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

  /// Rides: every passenger vehicle (Auto Priority is a booking tier autos serve, not a vehicle); bikes and scooties
  /// get small parcels too ("Parcels too"). Deliveries: the goods vehicles.
  List<VehicleKind> get _options => _draft.workType == WorkType.rides
      ? const [VehicleKind.bike, VehicleKind.scooty, VehicleKind.auto, VehicleKind.cab, VehicleKind.sedan, VehicleKind.suv]
      : const [
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
      showTtSnack(context, "We'll call you about pricing");
      return;
    }
    setState(() => _selected = k);
  }

  void _continue() {
    if (widget.showcase) return showTtSnack(context, kPreviewNote);
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
      backgroundColor: TtColors.surface,
      appBar: SignupAppBar(title: 'Choose your vehicle', step: 2, onBack: backOr(context, Routes.workType)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(TtSpacing.l, TtSpacing.xl, TtSpacing.l, TtSpacing.l),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(rides ? 'Which vehicle do you drive?' : 'Which goods vehicle do you drive?', style: t.h1),
                  const SizedBox(height: TtSpacing.xs),
                  Text(
                      plansOn
                          ? '${rides ? 'Rides' : 'Deliveries'} · one flat plan per month, no commission.'
                          : rides
                          ? 'Pick the vehicle you drive. Bikes, scooties and autos can take parcels too.'
                          : 'Pick the vehicle you drive, by how much load it can carry.',
                      style: t.body.copyWith(color: TtColors.navy700)),
                  const SizedBox(height: TtSpacing.l),
                  for (final row in rows) ...[
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = 0; i < row.length; i++) ...[
                            if (i > 0) const SizedBox(width: TtSpacing.m),
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
                    const SizedBox(height: TtSpacing.m),
                  ],
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
    final name = kind.label;
    // "Tata Ace", "Bolero"…
    final hint = Seed.vehicle(kind).modelHint;
    return Semantics(
      selected: selected,
      button: true,
      label: '$name, ${capacityText(kind)}${free ? '' : price == null ? ', price on request' : ', ${formatInr(price)} per month'}',
      excludeSemantics: true,
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
            padding: const EdgeInsets.all(TtSpacing.m),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Align(alignment: Alignment.centerLeft, child: VehicleArt(kind, width: 96, height: 60))),
                    Icon(
                      selected ? Symbols.radio_button_checked_rounded : Symbols.radio_button_unchecked_rounded,
                      color: selected ? TtColors.coral600 : TtColors.navy500,
                      size: 26,
                    ),
                  ],
                ),
                const SizedBox(height: TtSpacing.s),
                Text(name, style: t.h2.copyWith(fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: TtSpacing.xs),
                Row(children: [
                  Icon(kind.isGoods ? Symbols.weight_rounded : Symbols.group_rounded, size: 18, color: TtColors.navy700),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(capacityText(kind),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TtTextStyles.tabular(t.bodyMedium.copyWith(color: TtColors.navy900))),
                  ),
                ]),
                if (hint != null) ...[
                  const SizedBox(height: 2),
                  Text(hint, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.caption.copyWith(color: TtColors.navy500)),
                ],
                if (free && DriverService.availableFor(kind).contains(DriverService.parcels)) ...[
                  const SizedBox(height: TtSpacing.s),
                  const _Tag(label: '+ Parcels', bg: TtColors.successTint, fg: TtColors.successText),
                ],
                if (!free) ...[
                const SizedBox(height: TtSpacing.s),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(price == null ? '₹—' : formatInr(price), style: t.otp),
                      const SizedBox(width: 4),
                      Text('/ month', style: t.bodySmall.copyWith(color: TtColors.navy500)),
                    ],
                  ),
                ),
                const SizedBox(height: TtSpacing.s),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    const _Tag(label: '1st month free', bg: TtColors.successTint, fg: TtColors.successText),
                    if (price == null) const _Tag(label: 'Contact us', bg: TtColors.coral50, fg: TtColors.coral600),
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

/// What [kind] carries: "1 passenger", "3 passengers", "Up to 750 kg", "Up to 1.5 tonnes".
@visibleForTesting
String capacityText(VehicleKind kind) {
  final v = Seed.vehicle(kind);
  final seats = v.seats;
  if (seats != null) return seats == 1 ? '1 passenger' : '$seats passengers';
  final kg = v.capacityKg ?? 0;
  if (kg < 1000) return 'Up to $kg kg';
  final tonnes = kg / 1000;
  final n = tonnes == tonnes.roundToDouble() ? tonnes.toStringAsFixed(0) : tonnes.toStringAsFixed(1);
  return 'Up to $n ${tonnes == 1 ? 'tonne' : 'tonnes'}';
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.bg, required this.fg});
  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: TtRadii.pillRadius),
        child: Text(label, style: context.type.bodySmallMedium.copyWith(color: fg, fontWeight: FontWeight.w600)),
      );
}
