import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';
import 'package:tamiltaxi_ui/tamiltaxi_ui.dart';

import '../../router/routes.dart';
import '../../state/shifting_flow.dart';
import '../parcel/widgets/parcel_widgets.dart';
import 'widgets/shifting_widgets.dart';

/// PH-03 House shifting · day and extras: the next 7 days each with its price (weekends cost more), a two-hour slot,
/// the vehicle (every goods truck's total, the suggested one marked), packing, and extras: taking furniture apart,
/// unpacking, more helpers. The price follows every choice. Review → PH-04.
class PH03ScheduleScreen extends ConsumerWidget {
  const PH03ScheduleScreen({super.key, this.showcase = false});

  /// Opened on its own from the Design gallery: render the sample plan, start no timers.
  final bool showcase;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = showcase ? ShiftingFlowState.sample() : ref.watch(shiftingFlowProvider);
    final flow = ref.read(shiftingFlowProvider.notifier);
    final d = s.details;
    final q = s.quote;
    final rates = s.pricing.shifting;
    final size = rates.size(d.homeSize);
    final now = DateTime.now();
    final open = ShiftingFlowController.slotsOpen(s.day, now);
    final helperRate = rates.helperRate(between: d.between);

    return ShiftingScaffold(
      title: 'House shifting',
      step: 3,
      bottom: ShiftingPriceBar(
        total: q?.lines.total,
        caption: q == null
            ? (s.quoteError ?? 'Getting the price…')
            : '${q.vehicle.label} · ${q.lines.helperCount} helpers · see the price',
        label: 'Review',
        onDetails: q == null ? null : () => showShiftingPrice(context, q, details: d),
        onPressed: showcase
            ? () {}
            : (q == null || !open.contains(s.slotHour) ? null : () => context.push(Routes.shiftingReview)),
      ),
      children: [
        ShiftingSection(
          title: 'Which day?',
          subtitle: rates.weekendPct > 0
              ? 'Weekdays cost less. Saturday and Sunday add ${rates.weekendPct}%.'
              : 'Each day with its price.',
          // Sized by the chips (font metrics differ between phones), scrolling sideways.
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < 7; i++) ...[
                    if (i > 0) const SizedBox(width: TtSpacing.s),
                    () {
                      final day = DateTime(now.year, now.month, now.day + i);
                      final price = q?.days.where((x) => DateUtils.isSameDay(x.date, day)).firstOrNull;
                      final none = ShiftingFlowController.slotsOpen(day, now).isEmpty;
                      return _DayChip(
                        day: day,
                        index: i,
                        total: price?.total,
                        weekend:
                            price?.weekend ?? GoodsModeRates.isIstWeekend(DateTime(day.year, day.month, day.day, 9)),
                        selected: DateUtils.isSameDay(day, s.day),
                        onTap: showcase || none ? null : () => flow.setDay(day),
                      );
                    }(),
                  ],
                ],
              ),
            ),
          ),
        ),
        ShiftingSection(
          title: 'What time?',
          subtitle: 'The movers reach within the slot.',
          child: Wrap(
            spacing: TtSpacing.s,
            runSpacing: TtSpacing.s,
            children: [
              for (final h in GoodsModeRates.slotHours)
                TtChip(
                  label: slotLabel(h),
                  selected: h == s.slotHour && open.contains(h),
                  onTap: showcase || !open.contains(h) ? null : () => flow.setSlot(h),
                ),
            ],
          ),
        ),
        ShiftingSection(
          title: 'Vehicle',
          subtitle: 'Bigger homes may need two trips in a smaller vehicle.',
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final kind in GoodsModeRates.goodsTrucks) ...[
                    if (kind != GoodsModeRates.goodsTrucks.first) const SizedBox(width: TtSpacing.s),
                    () {
                      final v = q?.vehicles.where((x) => x.kind == kind).firstOrNull;
                      return _VehicleChoice(
                        kind: kind,
                        total: v?.total,
                        suggested: v?.suggested ?? kind == size.vehicle,
                        selected: kind == (q?.vehicle ?? s.vehicleOrSuggested),
                        onTap: showcase ? null : () => flow.setVehicle(kind),
                      );
                    }(),
                  ],
                ],
              ),
            ),
          ),
        ),
        ShiftingSection(
          title: 'Packing',
          child: Column(
            children: [
              for (final p in PackingLevel.values)
                _PackingOption(
                  level: p,
                  price: switch (p) {
                    PackingLevel.none => 0,
                    PackingLevel.basic => size.basic,
                    PackingLevel.full => size.full,
                  },
                  selected: d.packing == p,
                  onTap: showcase ? null : () => flow.setPacking(p),
                ),
            ],
          ),
        ),
        ShiftingSection(
          title: 'Extras',
          child: Column(
            children: [
              _ExtraRow(
                icon: Symbols.handyman_rounded,
                title: 'Take apart and put back',
                subtitle: 'Beds, almirahs, tables · ${formatInr(rates.dismantlePerPiece)} a piece',
                trailing: CountStepper(
                  value: d.dismantlePieces,
                  max: GoodsModeRates.maxDismantlePieces,
                  label: '${d.dismantlePieces}',
                  semanticsLabel: 'Pieces to take apart',
                  dense: true,
                  onChanged: flow.setDismantle,
                ),
              ),
              const Divider(height: TtSpacing.l),
              _ExtraRow(
                icon: Symbols.unarchive_rounded,
                title: 'Unpacking at the new home',
                subtitle: '${formatInr(size.unpack)} · the cartons opened and things set out',
                trailing: Switch(value: d.unpack, onChanged: showcase ? null : flow.setUnpack),
              ),
              const Divider(height: TtSpacing.l),
              _ExtraRow(
                icon: Symbols.group_add_rounded,
                title: 'Extra helpers',
                subtitle:
                    '${size.helpers} come with ${d.homeSize == HomeSize.fewItems ? 'a few items' : 'a ${d.homeSize.label}'} · ${formatInr(helperRate)} each',
                trailing: CountStepper(
                  value: d.extraHelpers,
                  max: GoodsModeRates.maxExtraHelpers,
                  label: '+${d.extraHelpers}',
                  semanticsLabel: 'Extra helpers',
                  dense: true,
                  onChanged: flow.setExtraHelpers,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A day with its price ("Tomorrow · 3 Oct · ₹3,135"); weekends marked.
class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.day,
    required this.index,
    required this.total,
    required this.weekend,
    required this.selected,
    required this.onTap,
  });
  final DateTime day;
  final int index;
  final int? total;
  final bool weekend;
  final bool selected;
  final VoidCallback? onTap;

  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final name = index == 0
        ? 'Today'
        : index == 1
        ? 'Tomorrow'
        : _days[day.weekday - 1];
    final off = onTap == null && !selected;
    return Semantics(
      button: true,
      selected: selected,
      label:
          '$name ${day.day} ${_months[day.month - 1]}${total == null ? '' : ', ${formatInr(total!)}'}${off ? ', no slots left' : ''}',
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
          child: Container(
            width: 92,
            padding: const EdgeInsets.symmetric(horizontal: TtSpacing.s, vertical: TtSpacing.s),
            child: Opacity(
              opacity: off ? 0.45 : 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    style: t.caption.copyWith(
                      color: selected ? TtColors.coral700 : TtColors.navy500,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${day.day} ${_months[day.month - 1]}',
                    style: t.bodySemibold.copyWith(color: selected ? TtColors.coral700 : TtColors.navy900),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Flexible(
                        child: total == null
                            ? const SkeletonBox(width: 48, height: 12)
                            : Text(
                                formatInr(total!),
                                style: TtTextStyles.tabular(
                                  t.caption.copyWith(
                                    color: weekend ? TtColors.warningText : TtColors.successText,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                maxLines: 1,
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VehicleChoice extends StatelessWidget {
  const _VehicleChoice({
    required this.kind,
    required this.total,
    required this.suggested,
    required this.selected,
    required this.onTap,
  });
  final VehicleKind kind;
  final int? total;
  final bool suggested;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Semantics(
      button: true,
      selected: selected,
      label: '${kind.label}${suggested ? ', suggested' : ''}${total == null ? '' : ', ${formatInr(total!)}'}',
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
          child: Container(
            width: 132,
            padding: const EdgeInsets.all(TtSpacing.s),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 18,
                  child: suggested
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          decoration: const BoxDecoration(
                            color: TtColors.successTint,
                            borderRadius: TtRadii.pillRadius,
                          ),
                          child: Text(
                            'Suggested',
                            style: t.caption.copyWith(color: TtColors.successText, fontWeight: FontWeight.w700),
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: 4),
                Center(
                  child: ParcelVehicleArt(
                    kind: kind,
                    width: 96,
                    height: 52,
                    tile: selected ? TtColors.surface : TtColors.coral50,
                  ),
                ),
                const SizedBox(height: TtSpacing.s),
                Text(kind.label, style: t.bodySemibold, maxLines: 1, overflow: TextOverflow.ellipsis),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        kind.bedLabel ?? '',
                        style: t.caption.copyWith(color: TtColors.navy500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (total != null)
                      Text(
                        formatInr(total!),
                        style: TtTextStyles.tabular(
                          t.caption.copyWith(color: TtColors.navy900, fontWeight: FontWeight.w700),
                        ),
                      ),
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

class _PackingOption extends StatelessWidget {
  const _PackingOption({required this.level, required this.price, required this.selected, required this.onTap});
  final PackingLevel level;
  final int price;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Padding(
      padding: const EdgeInsets.only(bottom: TtSpacing.s),
      child: Semantics(
        button: true,
        selected: selected,
        label: '${level.label} packing, ${price == 0 ? 'free' : formatInr(price)}. ${level.hint}',
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
                  Icon(
                    selected ? Symbols.radio_button_checked_rounded : Symbols.radio_button_unchecked_rounded,
                    color: selected ? TtColors.coral600 : TtColors.navy300,
                  ),
                  const SizedBox(width: TtSpacing.m),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(level.label, style: t.bodySemibold),
                        Text(level.hint, style: t.bodySmall.copyWith(color: TtColors.navy500)),
                      ],
                    ),
                  ),
                  const SizedBox(width: TtSpacing.s),
                  Text(price == 0 ? 'Free' : formatInr(price), style: TtTextStyles.tabular(t.bodySemibold)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ExtraRow extends StatelessWidget {
  const _ExtraRow({required this.icon, required this.title, required this.subtitle, required this.trailing});
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Row(
      children: [
        Icon(icon, size: 22, color: TtColors.navy700),
        const SizedBox(width: TtSpacing.m),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: t.bodySemibold),
              Text(subtitle, style: t.caption.copyWith(color: TtColors.navy500)),
            ],
          ),
        ),
        const SizedBox(width: TtSpacing.s),
        trailing,
      ],
    );
  }
}
