import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

import '../../state/driver_session.dart';
import '../states/s15_empty_earnings_view.dart';
import 'd23b_trip_detail_sheet.dart';
import 'widgets/earnings_header.dart';

/// D-23 Earnings: Today / Week / Month tabs, big total, "You kept 100%", bar chart (the
/// best bar in coral-500), stat tiles and the trip list (tap → D-23b). Empty → S-15.
class D23EarningsScreen extends ConsumerStatefulWidget {
  const D23EarningsScreen({super.key, this.showcase = false});

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  @override
  ConsumerState<D23EarningsScreen> createState() => _D23EarningsScreenState();
}

class _D23EarningsScreenState extends ConsumerState<D23EarningsScreen> {
  EarningsPeriod _period = EarningsPeriod.week;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(earningsProvider(_period));
    final summary = async.value;
    final empty = summary != null && summary.rides == 0 && summary.trips.isEmpty;

    final Widget body;
    if (async.hasError && summary == null) {
      body = Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(RidoSpacing.gutter),
          child: EmptyState(
            illustration: const RidoIllustration(IllustrationKind.offline, height: 160),
            title: "You're offline",
            message: 'Check your internet connection and try again.',
            actionLabel: 'Retry',
            onAction: () => ref.invalidate(earningsProvider(_period)),
          ),
        ),
      );
    } else if (summary == null) {
      body = const _EarningsSkeleton();
    } else if (empty) {
      body = S15EmptyEarningsView(period: _period);
    } else {
      body = RefreshIndicator(
        color: RidoColors.coral600,
        onRefresh: () => ref.refresh(earningsProvider(_period).future),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(RidoSpacing.gutter, RidoSpacing.l, RidoSpacing.gutter, RidoSpacing.xl),
          children: [
            _ChartCard(bars: summary.bars),
            const SizedBox(height: RidoSpacing.m),
            Row(children: [
              Expanded(child: _StatTile(value: formatCount(summary.rides), label: 'rides')),
              const SizedBox(width: RidoSpacing.s),
              Expanded(child: _StatTile(value: '${summary.onlineHours}h', label: 'online')),
              const SizedBox(width: RidoSpacing.s),
              Expanded(child: _StatTile(value: summary.rating.toStringAsFixed(1), label: 'rating', star: true)),
            ]),
            const SizedBox(height: RidoSpacing.m),
            _TripList(trips: summary.trips),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: RidoColors.background,
      body: Column(children: [
        EarningsHeader(
          period: _period,
          onPeriod: (p) => setState(() => _period = p),
          total: summary?.total,
          commissionSaved: summary == null || empty ? null : summary.commissionSaved,
        ),
        Expanded(child: body),
      ]),
    );
  }
}

String _short(int v) {
  if (v < 1000) return '$v';
  final k = v / 1000;
  return k >= 10 ? '${k.round()}k' : '${k.toStringAsFixed(1)}k';
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.bars});
  final List<EarningsDay> bars;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    if (bars.isEmpty) return const SizedBox.shrink();
    final maxV = bars.map((b) => b.amount).reduce((a, b) => a > b ? a : b);
    final maxIndex = bars.indexWhere((b) => b.amount == maxV);
    return RidoCard(
      padding: const EdgeInsets.fromLTRB(RidoSpacing.m, RidoSpacing.xl, RidoSpacing.m, RidoSpacing.s),
      child: SizedBox(
        height: 190,
        child: Semantics(
          label: 'Earnings chart. ${[for (final b in bars) '${b.label} ${formatInr(b.amount)}'].join(', ')}',
          child: BarChart(
            BarChartData(
              maxY: maxV * 1.22,
              minY: 0,
              alignment: BarChartAlignment.spaceAround,
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              barTouchData: BarTouchData(
                enabled: false,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => Colors.transparent,
                  tooltipPadding: EdgeInsets.zero,
                  tooltipMargin: 4,
                  getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                    _short(rod.toY.round()),
                    RidoTextStyles.tabular(t.caption.copyWith(color: RidoColors.navy700, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                topTitles: const AxisTitles(),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (v, meta) => SideTitleWidget(
                      meta: meta,
                      child: Text(bars[v.toInt()].label, style: t.bodySmall.copyWith(color: RidoColors.navy500)),
                    ),
                  ),
                ),
              ),
              barGroups: [
                for (var i = 0; i < bars.length; i++)
                  BarChartGroupData(
                    x: i,
                    showingTooltipIndicators: const [0],
                    barRods: [
                      BarChartRodData(
                        toY: bars[i].amount.toDouble(),
                        width: bars.length > 5 ? 32 : 44,
                        color: i == maxIndex ? RidoColors.coral500 : RidoColors.coral100,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
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

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label, this.star = false});
  final String value;
  final String label;
  final bool star;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return RidoCard(
      padding: const EdgeInsets.symmetric(horizontal: RidoSpacing.m, vertical: RidoSpacing.m),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Flexible(child: FittedBox(child: Text(value, style: RidoTextStyles.tabular(t.h1)))),
          if (star) ...[
            const SizedBox(width: 4),
            const Icon(Symbols.star_rounded, fill: 1, color: RidoColors.warning, size: 22),
          ],
        ]),
        Text(label, style: t.bodySmall.copyWith(color: RidoColors.navy500)),
      ]),
    );
  }
}

class _TripList extends StatelessWidget {
  const _TripList({required this.trips});
  final List<EarningsTrip> trips;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return RidoCard(
      padding: EdgeInsets.zero,
      child: Column(children: [
        for (var i = 0; i < trips.length; i++) ...[
          if (i > 0) const Divider(),
          InkWell(
            onTap: () => D23bTripDetailSheet.show(context, trips[i]),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: RidoSpacing.l, vertical: RidoSpacing.l),
              child: Row(children: [
                SizedBox(
                  width: 72,
                  child: Text(formatTime(trips[i].time),
                      style: RidoTextStyles.tabular(t.bodySmall.copyWith(color: RidoColors.navy500))),
                ),
                Expanded(
                  child: Text('${trips[i].from} → ${trips[i].to}',
                      style: t.body, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: RidoSpacing.s),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: RidoSpacing.s, vertical: 3),
                  decoration: BoxDecoration(color: RidoColors.inputBg, borderRadius: BorderRadius.circular(6)),
                  child: Text(trips[i].paymentMode == PaymentMode.upi ? 'UPI' : 'Cash',
                      style: t.caption.copyWith(color: RidoColors.navy700, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: RidoSpacing.m),
                Text(formatInr(trips[i].fare), style: RidoTextStyles.tabular(t.bodySemibold)),
              ]),
            ),
          ),
        ],
      ]),
    );
  }
}

class _EarningsSkeleton extends StatelessWidget {
  const _EarningsSkeleton();

  @override
  Widget build(BuildContext context) => SkeletonShimmer(
        child: ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(RidoSpacing.gutter, RidoSpacing.l, RidoSpacing.gutter, RidoSpacing.l),
          children: [
            const SkeletonBox(height: 220, radius: RidoRadii.card),
            const SizedBox(height: RidoSpacing.m),
            Row(children: const [
              Expanded(child: SkeletonBox(height: 84, radius: RidoRadii.card)),
              SizedBox(width: RidoSpacing.s),
              Expanded(child: SkeletonBox(height: 84, radius: RidoRadii.card)),
              SizedBox(width: RidoSpacing.s),
              Expanded(child: SkeletonBox(height: 84, radius: RidoRadii.card)),
            ]),
            const SizedBox(height: RidoSpacing.m),
            for (var i = 0; i < 4; i++) ...[
              const SkeletonBox(height: 56, radius: RidoRadii.card),
              const SizedBox(height: RidoSpacing.s),
            ],
          ],
        ),
      );
}
