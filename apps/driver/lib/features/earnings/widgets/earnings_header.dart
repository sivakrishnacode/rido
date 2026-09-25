import 'package:flutter/material.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

import '../../home/widgets/navy_header.dart';

/// "this week", "today", "this month".
String periodSuffix(EarningsPeriod p) => switch (p) {
      EarningsPeriod.today => 'today',
      EarningsPeriod.week => 'this week',
      EarningsPeriod.month => 'this month',
    };

/// D-23 / S-15 navy header: title, Today / Week / Month tabs, the big total and the
/// commission-saved line. [total] null shows a skeleton.
class EarningsHeader extends StatelessWidget {
  const EarningsHeader({
    super.key,
    required this.period,
    required this.onPeriod,
    required this.total,
    this.commissionSaved,
  });

  final EarningsPeriod period;
  final ValueChanged<EarningsPeriod> onPeriod;
  final int? total;

  /// Null hides the "You kept 100%" line (empty state).
  final int? commissionSaved;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return NavyHeader(
      padding: const EdgeInsets.fromLTRB(RidoSpacing.gutter, RidoSpacing.l, RidoSpacing.gutter, RidoSpacing.xl),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Earnings', style: t.display.copyWith(color: Colors.white)),
        const SizedBox(height: RidoSpacing.l),
        RidoSegmented<EarningsPeriod>(
          dark: true,
          options: EarningsPeriod.values,
          labelOf: (p) => switch (p) {
            EarningsPeriod.today => 'Today',
            EarningsPeriod.week => 'Week',
            EarningsPeriod.month => 'Month',
          },
          selected: period,
          onChanged: onPeriod,
        ),
        const SizedBox(height: RidoSpacing.xl),
        if (total == null)
          const Align(
            alignment: Alignment.centerLeft,
            child: SkeletonShimmer(child: SkeletonBox(width: 240, height: 44)),
          )
        else
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text('${formatInr(total!)} ${periodSuffix(period)}', style: t.heroSmall.copyWith(color: Colors.white)),
          ),
        if (commissionSaved != null) ...[
          const SizedBox(height: RidoSpacing.s),
          Text.rich(
            TextSpan(children: [
              const TextSpan(text: 'You kept 100%. Commission saved: '),
              TextSpan(
                text: '~${formatInr(commissionSaved!)}',
                style: t.bodySemibold.copyWith(color: Colors.white),
              ),
            ]),
            style: RidoTextStyles.tabular(t.body.copyWith(color: Colors.white.withValues(alpha: 0.85))),
          ),
        ],
      ]),
    );
  }
}
