import 'package:flutter/material.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';
import 'package:tamiltaxi_ui/tamiltaxi_ui.dart';

/// A house shift's job sheet (D-21 "See items"): the home and the team, both ends' floors and lifts, the extras the
/// customer booked, and every item as they typed it.
Future<void> showShiftingDetails(BuildContext context, RideRequest job) {
  final s = job.shifting;
  if (s == null) return Future.value();
  return showTtSheet<void>(context, builder: (ctx) => _ShiftingDetails(job: job, s: s));
}

class _ShiftingDetails extends StatelessWidget {
  const _ShiftingDetails({required this.job, required this.s});
  final RideRequest job;
  final ShiftingDetails s;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final helpers = s.lines?.helperCount;
    final extras = s.extrasLabels;
    Widget end(String label, String place, int floor, bool lift) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 56, child: Text(label, style: t.caption.copyWith(color: TtColors.navy500))),
          Expanded(
            child: Text.rich(TextSpan(children: [
              TextSpan(text: place, style: t.bodySmall.copyWith(color: TtColors.navy900, fontWeight: FontWeight.w600)),
              TextSpan(text: ' · ${floorLabel(floor, lift)}', style: t.bodySmall.copyWith(color: TtColors.navy700)),
            ])),
          ),
        ]);
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Text('House shifting · ${s.homeSize.label}', style: t.h2),
          const SizedBox(height: 4),
          Text(
            [
              job.vehicle.label,
              if (helpers != null) 'bring $helpers helper${helpers == 1 ? '' : 's'}',
              if (s.between) 'to another town',
            ].join(' · '),
            style: t.bodySmall.copyWith(color: TtColors.navy700),
          ),
          const SizedBox(height: TtSpacing.l),
          end('From', job.pickup.name, s.pickupFloor, s.pickupLift),
          const SizedBox(height: TtSpacing.s),
          end('To', job.drop.name, s.dropFloor, s.dropLift),
          if (extras.isNotEmpty) ...[
            const SizedBox(height: TtSpacing.l),
            Wrap(spacing: TtSpacing.s, runSpacing: TtSpacing.s, children: [
              for (final e in extras)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: const BoxDecoration(color: TtColors.coral50, borderRadius: TtRadii.pillRadius),
                  child: Text(e, style: t.bodySmallMedium.copyWith(color: TtColors.coral700)),
                ),
            ]),
          ],
          const SizedBox(height: TtSpacing.l),
          Text('${s.items.length} ITEMS · ${s.itemCount} IN ALL', style: t.overline),
          const SizedBox(height: TtSpacing.s),
          for (final i in s.items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 36,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  decoration: const BoxDecoration(color: TtColors.inputBg, borderRadius: TtRadii.pillRadius),
                  child: Text('×${i.qty}', style: TtTextStyles.tabular(t.caption.copyWith(fontWeight: FontWeight.w700))),
                ),
                const SizedBox(width: TtSpacing.m),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(i.name, style: t.bodySemibold),
                    if (i.note.isNotEmpty) Text(i.note, style: t.bodySmall.copyWith(color: TtColors.navy500)),
                  ]),
                ),
              ]),
            ),
          const SizedBox(height: TtSpacing.l),
          TtButton(label: 'Close', onPressed: () => Navigator.of(context).pop()),
        ]),
      ),
    );
  }
}
