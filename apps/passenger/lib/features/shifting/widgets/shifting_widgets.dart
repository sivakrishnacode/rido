import 'package:flutter/material.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';
import 'package:tamiltaxi_ui/tamiltaxi_ui.dart';

/// The three planning steps of a house shift.
const shiftingSteps = ['Moving', 'Items', 'Day & extras'];

/// A house-shifting screen: app bar, the step bar ([step] 1–3; null on the review), a scrolling body and a pinned
/// [bottom] (usually [ShiftingPriceBar]).
class ShiftingScaffold extends StatelessWidget {
  const ShiftingScaffold({super.key, required this.title, this.step, required this.children, required this.bottom, this.onBack});

  final String title;
  final int? step;
  final List<Widget> children;
  final Widget bottom;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: TtColors.background,
        appBar: TtAppBar(title: title, onBack: onBack),
        body: Column(
          children: [
            if (step case final s?) _StepBar(step: s),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(TtSpacing.l, TtSpacing.m, TtSpacing.l, TtSpacing.xl),
                children: children,
              ),
            ),
            bottom,
          ],
        ),
      );
}

/// Three thin bars with the step names under them; done and current steps in coral.
class _StepBar extends StatelessWidget {
  const _StepBar({required this.step});
  final int step;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Semantics(
      label: 'Step $step of ${shiftingSteps.length}: ${shiftingSteps[step - 1]}',
      excludeSemantics: true,
      child: Container(
        color: TtColors.surface,
        padding: const EdgeInsets.fromLTRB(TtSpacing.l, 0, TtSpacing.l, TtSpacing.m),
        child: Row(
          children: [
            for (var i = 1; i <= shiftingSteps.length; i++) ...[
              if (i > 1) const SizedBox(width: TtSpacing.s),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      height: 4,
                      decoration: BoxDecoration(
                        color: i <= step ? TtColors.coral600 : TtColors.divider,
                        borderRadius: TtRadii.pillRadius,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      shiftingSteps[i - 1],
                      style: t.caption.copyWith(
                        color: i == step ? TtColors.navy900 : TtColors.navy500,
                        fontWeight: i == step ? FontWeight.w600 : null,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A white card with a title (and an optional line under it, or a [trailing] on the right).
class ShiftingSection extends StatelessWidget {
  const ShiftingSection({super.key, required this.title, required this.child, this.subtitle, this.trailing});

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Container(
      margin: const EdgeInsets.only(bottom: TtSpacing.m),
      padding: const EdgeInsets.all(TtSpacing.l),
      decoration: BoxDecoration(
        color: TtColors.surface,
        borderRadius: TtRadii.cardRadius,
        border: Border.all(color: TtColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: t.bodySemibold)),
              ?trailing,
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!, style: t.bodySmall.copyWith(color: TtColors.navy500)),
          ],
          const SizedBox(height: TtSpacing.m),
          child,
        ],
      ),
    );
  }
}

/// A − value + stepper (floors, pieces, helpers).
class CountStepper extends StatelessWidget {
  const CountStepper({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
    this.min = 0,
    this.max = 99,
    this.semanticsLabel,
    this.dense = false,
  });

  /// Smaller buttons and value, for rows with a title beside them.
  final bool dense;

  final int value;
  final ValueChanged<int> onChanged;

  /// What [value] reads as ("2nd", "3 pieces").
  final String label;
  final int min;
  final int max;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    Widget button(IconData icon, String tip, int? next) => IconButton(
          tooltip: tip,
          onPressed: next == null ? null : () => onChanged(next),
          style: IconButton.styleFrom(
            backgroundColor: next == null ? TtColors.inputBg : TtColors.coral50,
            foregroundColor: TtColors.coral600,
            disabledForegroundColor: TtColors.navy300,
            minimumSize: Size.square(dense ? 34 : 40),
            fixedSize: dense ? const Size.square(34) : null,
            padding: dense ? EdgeInsets.zero : null,
          ),
          icon: Icon(icon, size: dense ? 18 : 20),
        );
    return Semantics(
      label: semanticsLabel,
      value: label,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          button(Symbols.remove_rounded, 'Less', value > min ? value - 1 : null),
          ConstrainedBox(
            constraints: BoxConstraints(minWidth: dense ? 32 : 64),
            child: Text(label, textAlign: TextAlign.center, style: TtTextStyles.tabular(t.bodySemibold)),
          ),
          button(Symbols.add_rounded, 'More', value < max ? value + 1 : null),
        ],
      ),
    );
  }
}

/// "Ground", "1st", "2nd" … (the floor stepper's value).
String floorShort(int floor) {
  if (floor <= 0) return 'Ground';
  return floorLabel(floor, false).split(' ').first;
}

/// One end of the move, compact: the place (tap to change; the green dot is the old home, the pin the new one), its
/// floor and, above the ground floor, whether there is a lift.
class MoveEndCard extends StatelessWidget {
  const MoveEndCard({
    super.key,
    required this.isPickup,
    required this.place,
    required this.floor,
    required this.lift,
    required this.onPlace,
    required this.onFloor,
    required this.onLift,
    this.stairsPerFloor = GoodsModeRates.stairsPerFloor,
  });

  /// The city's stairs charge per floor without a lift.
  final int stairsPerFloor;
  final bool isPickup;
  final Place? place;
  final int floor;
  final bool lift;
  final VoidCallback? onPlace;
  final ValueChanged<int> onFloor;
  final ValueChanged<bool> onLift;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final p = place;
    return Container(
      margin: const EdgeInsets.only(bottom: TtSpacing.s),
      decoration: BoxDecoration(
        color: TtColors.surface,
        borderRadius: TtRadii.cardRadius,
        border: Border.all(color: TtColors.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            label: '${isPickup ? 'Moving from' : 'Moving to'} ${p?.name ?? 'not chosen yet'}',
            excludeSemantics: true,
            child: InkWell(
              onTap: onPlace,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(TtSpacing.m, 10, TtSpacing.s, 10),
                child: Row(
                  children: [
                    SizedBox(width: 24, child: Center(child: isPickup ? const PickupDot(size: 10) : const DropPin(size: 22))),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p?.name ?? 'Choose the new home',
                            style: t.bodySemibold.copyWith(color: p == null ? TtColors.coral600 : TtColors.navy900),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (p != null && p.address.isNotEmpty)
                            Text(p.address, style: t.bodySmall.copyWith(color: TtColors.navy500), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    const Icon(Symbols.chevron_right_rounded, color: TtColors.navy500),
                  ],
                ),
              ),
            ),
          ),
          const Divider(height: 1, indent: TtSpacing.m, endIndent: TtSpacing.m),
          Padding(
            padding: const EdgeInsets.fromLTRB(TtSpacing.m, 0, TtSpacing.xs, 0),
            child: Row(
              children: [
                const Icon(Symbols.stairs_2_rounded, size: 20, color: TtColors.navy700),
                const SizedBox(width: TtSpacing.s),
                Expanded(child: Text('Floor', style: t.bodySmallMedium.copyWith(color: TtColors.navy700))),
                CountStepper(
                  dense: true,
                  value: floor,
                  max: GoodsModeRates.maxFloor,
                  label: floorShort(floor),
                  semanticsLabel: isPickup ? 'Floor at the old home' : 'Floor at the new home',
                  onChanged: onFloor,
                ),
              ],
            ),
          ),
          // Above the ground floor: is there a lift big enough for furniture?
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            alignment: Alignment.topCenter,
            child: floor == 0
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.fromLTRB(TtSpacing.m, 0, TtSpacing.xs, TtSpacing.xs),
                    child: Row(
                      children: [
                        const Icon(Symbols.elevator_rounded, size: 20, color: TtColors.navy700),
                        const SizedBox(width: TtSpacing.s),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Lift for furniture', style: t.bodySmallMedium.copyWith(color: TtColors.navy700)),
                              Text(
                                lift ? 'No stairs charge' : '${formatInr(stairsPerFloor)} a floor by the stairs',
                                style: t.caption.copyWith(color: TtColors.navy500),
                              ),
                            ],
                          ),
                        ),
                        Switch(value: lift, onChanged: onLift),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// One home size to choose (PH-01).
class HomeSizeTile extends StatelessWidget {
  const HomeSizeTile({super.key, required this.size, required this.selected, required this.onTap});
  final HomeSize size;
  final bool selected;
  final VoidCallback? onTap;

  static IconData iconOf(HomeSize s) => switch (s) {
        HomeSize.fewItems => Symbols.package_2_rounded,
        HomeSize.oneRk => Symbols.bed_rounded,
        HomeSize.oneBhk => Symbols.cottage_rounded,
        HomeSize.twoBhk => Symbols.home_rounded,
        HomeSize.threeBhk => Symbols.villa_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Semantics(
      button: true,
      selected: selected,
      label: '${size.label}. ${size.hint}',
      excludeSemantics: true,
      child: Material(
        color: selected ? TtColors.coral50 : TtColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: TtRadii.cardRadius,
          side: BorderSide(color: selected ? TtColors.coral600 : TtColors.divider, width: selected ? 1.5 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(TtSpacing.m),
            child: Row(
              children: [
                Icon(iconOf(size), color: selected ? TtColors.coral600 : TtColors.navy700, fill: selected ? 1 : 0),
                const SizedBox(width: TtSpacing.s),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(size.label,
                          style: t.bodySemibold.copyWith(color: selected ? TtColors.coral700 : TtColors.navy900),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      Text(size.hint, style: t.caption.copyWith(color: TtColors.navy500), maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The pinned bottom: the total so far (or what is missing) and the next step's button.
class ShiftingPriceBar extends StatelessWidget {
  const ShiftingPriceBar({
    super.key,
    required this.total,
    required this.label,
    required this.onPressed,
    this.caption,
    this.loading = false,
    this.pricing = true,
    this.onDetails,
  });

  /// Null while it is being priced, or when there is nothing to price yet (see [pricing]).
  final int? total;

  /// A null [total] is on its way (a placeholder shows); false: nothing to price yet, the [caption] says why.
  final bool pricing;
  final String label;
  final VoidCallback? onPressed;

  /// Under the total: "2 helpers · Pickup truck", "Add a drop to see the price".
  final String? caption;
  final bool loading;

  /// Opens the price lines.
  final VoidCallback? onDetails;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Container(
      decoration: const BoxDecoration(
        color: TtColors.surface,
        border: Border(top: BorderSide(color: TtColors.divider)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(TtSpacing.l, TtSpacing.m, TtSpacing.l, TtSpacing.m),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: onDetails,
                  borderRadius: TtRadii.cardRadius,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: total != null
                                  ? Text(formatInr(total!), key: ValueKey(total), style: TtTextStyles.tabular(t.h2))
                                  : pricing
                                      ? const SkeletonBox(key: ValueKey('pricing'), width: 72, height: 24)
                                      : const SizedBox.shrink(key: ValueKey('nothing')),
                            ),
                            if (onDetails != null && total != null) ...[
                              const SizedBox(width: 2),
                              const Icon(Symbols.expand_less_rounded, size: 20, color: TtColors.navy500),
                            ],
                          ],
                        ),
                        if (caption != null)
                          Text(
                            caption!,
                            // On its own (nothing priced yet) it is the bar's only line: a size up.
                            style: total == null && !pricing
                                ? t.bodySmall.copyWith(color: TtColors.navy700)
                                : t.caption.copyWith(color: TtColors.navy500),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: TtSpacing.m),
              TtButton(label: label, expand: false, loading: loading, onPressed: onPressed),
            ],
          ),
        ),
      ),
    );
  }
}

/// The price lines of a shift, in the fare-breakdown style.
FareBreakdown shiftingBreakdown(
  ShiftingLines l, {
  required VehicleKind vehicle,
  ShiftingDetails? details,
  String? title,
  String? subtitle,
  bool between = false,
}) =>
    FareBreakdown.fromShifting(l, vehicle: vehicle, details: details, between: between, title: title, subtitle: subtitle);

/// Opens the price lines in a sheet.
Future<void> showShiftingPrice(BuildContext context, ShiftingQuote q, {required ShiftingDetails details}) => showTtSheet<void>(
      context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          shiftingBreakdown(q.lines,
              vehicle: q.vehicle,
              details: details,
              between: details.between,
              title: 'Price',
              subtitle: '${q.vehicle.label} · ${formatKm(q.distanceKm)}'),
          const SizedBox(height: TtSpacing.s),
          Text('Fixed before you book. Pay the driver by cash or UPI; tolls and parking on the way are yours.',
              style: ctx.type.caption.copyWith(color: TtColors.navy500)),
          const SizedBox(height: TtSpacing.l),
          TtButton(label: 'Got it', onPressed: () => Navigator.of(ctx).pop()),
        ],
      ),
    );
