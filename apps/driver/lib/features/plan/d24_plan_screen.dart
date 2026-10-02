import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';
import 'package:tamiltaxi_ui/tamiltaxi_ui.dart';

import '../../common/load_error.dart';
import '../../router/routes.dart';
import '../../state/driver_account.dart';
import '../../state/driver_session.dart';
import '../home/widgets/navy_header.dart';

/// D-24 Plan (subscription), with D-24b (paused) and D-24c (cancelled): status card, savings
/// callout, payment history, Change UPI app / Pause plan / Cancel plan; grace and expired
/// show "Pay ₹2,000 now". [previewStatus] overrides the shown status without changing it.
class D24PlanScreen extends ConsumerWidget {
  const D24PlanScreen({super.key, this.previewStatus, this.showcase = false});

  /// Gallery variants D-24b (paused) / D-24c (cancelled).
  final PlanStatus? previewStatus;

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  Future<void> _run(BuildContext context, Future<void> Function() action, String done) async {
    try {
      await action();
      if (context.mounted) showTtSnack(context, done, success: true);
    } on OfflineException {
      if (context.mounted) showTtSnack(context, "You're offline. Try again.");
    } on ApiException catch (e) {
      if (context.mounted) showTtSnack(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.type;
    final planAsync = ref.watch(planProvider);
    final plan = planAsync.value;
    final payments = ref.watch(paymentsProvider).value;
    // Live API: the month's commission saved from the earnings endpoint (no lifetime figure yet).
    final live = !showcase && ref.watch(isLiveApiProvider);
    final monthSaved = live ? ref.watch(earningsProvider(EarningsPeriod.month)).value?.commissionSaved : null;
    final notifier = ref.read(planProvider.notifier);

    if (plan == null && planAsync.hasError) {
      return Scaffold(
        backgroundColor: TtColors.background,
        body: Column(children: [
          _header(t),
          Expanded(
            child: LoadError(error: planAsync.error!, what: 'your plan', onRetry: () => ref.invalidate(planProvider)),
          ),
        ]),
      );
    }
    if (plan == null) {
      return Scaffold(
        backgroundColor: TtColors.background,
        body: Column(children: [
          _header(t),
          const Expanded(
            child: SkeletonShimmer(
              child: Padding(
                padding: EdgeInsets.all(TtSpacing.gutter),
                child: Column(children: [
                  SkeletonBox(height: 200, radius: TtRadii.card),
                  SizedBox(height: TtSpacing.m),
                  SkeletonBox(height: 80, radius: TtRadii.card),
                  SizedBox(height: TtSpacing.m),
                  SkeletonBox(height: 140, radius: TtRadii.card),
                ]),
              ),
            ),
          ),
        ]),
      );
    }

    final status = previewStatus ?? plan.status;
    final price = plan.monthlyPrice;
    final priceText = price == null ? '₹—' : formatInr(price);
    final end = formatDate(plan.nextDebit);
    void pay() => context.push(Routes.autopay(purpose: 'pay'));

    Future<void> pause() async {
      final ok = await showTtConfirm(
        context,
        title: 'Pause your plan?',
        message: "You can't go online while paused. No auto-debits until you resume.",
        confirmLabel: 'Pause plan',
        cancelLabel: 'Keep plan active',
        icon: Symbols.pause_circle_rounded,
      );
      if (ok && context.mounted) await _run(context, notifier.pause, 'Plan paused');
    }

    Future<void> cancel() async {
      final ok = await showTtConfirm(
        context,
        title: 'Cancel your plan?',
        message: 'Your plan stays active till $end. No more auto-debits after that.',
        confirmLabel: 'Cancel plan',
        cancelLabel: 'Keep plan',
        destructive: true,
        icon: Symbols.cancel_rounded,
      );
      if (ok && context.mounted) await _run(context, notifier.cancel, 'Plan cancelled · active till $end');
    }

    // ------------------------------------------------------------ status card
    final (StatusKind pillKind, String pillLabel) = switch (status) {
      PlanStatus.trial || PlanStatus.active => (StatusKind.active, 'Active'),
      PlanStatus.grace => (StatusKind.grace, 'Grace'),
      PlanStatus.expired => (StatusKind.expired, 'Expired'),
      PlanStatus.paused => (StatusKind.paused, 'Paused'),
      PlanStatus.cancelled => (StatusKind.cancelled, 'Cancelled'),
    };
    final (String caption, String headline) = switch (status) {
      PlanStatus.trial || PlanStatus.active => ('Next auto-debit', '$priceText on $end'),
      PlanStatus.grace => ('Payment failed · ${plan.graceDaysLeft} days left', 'Pay $priceText by ${formatDate(plan.nextDebit.add(Duration(days: plan.graceDaysLeft)))}'),
      PlanStatus.expired => ('Plan expired on ${formatDate(TtClock.today)}', 'Renew to go online'),
      PlanStatus.paused => ('Paused on ${formatDate(TtClock.today)}', '30 trial days saved for later'),
      PlanStatus.cancelled => ('Cancelled, active till', end),
    };
    final statusCard = TtCard(
      shadow: true,
      borderColor: null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('${plan.vehicle.label} plan', style: t.h1)),
          if (status == PlanStatus.trial) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: const BoxDecoration(color: TtColors.coral50, borderRadius: TtRadii.pillRadius),
              child: Text('Free trial', style: t.caption.copyWith(color: TtColors.coral600, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: TtSpacing.s),
          ],
          StatusPill(pillKind, label: pillLabel, large: true),
        ]),
        const SizedBox(height: TtSpacing.l),
        Text(caption, style: t.body.copyWith(color: TtColors.navy500)),
        Text(headline, style: TtTextStyles.tabular(t.h1)),
        const SizedBox(height: TtSpacing.l),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: TtSpacing.l, vertical: TtSpacing.m),
          decoration: const BoxDecoration(color: TtColors.inputBg, borderRadius: TtRadii.cardRadius),
          child: Row(children: [
            if (status == PlanStatus.cancelled)
              const Icon(Symbols.event_busy_rounded, color: TtColors.navy700)
            else
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: TtColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: TtColors.divider),
                ),
                child: Text(plan.upiApp.substring(0, 1), style: t.caption.copyWith(fontWeight: FontWeight.w700, color: TtColors.navy900)),
              ),
            const SizedBox(width: TtSpacing.m),
            Expanded(
              child: Text(status == PlanStatus.cancelled ? 'No more auto-debits' : 'UPI Autopay: ${plan.upiApp}',
                  style: t.body),
            ),
            if (status == PlanStatus.paused)
              Text('Paused', style: t.bodySmallMedium.copyWith(color: TtColors.navy500))
            else
              const Icon(Symbols.check_circle_rounded, color: TtColors.success, fill: 1),
          ]),
        ),
      ]),
    );

    final savings = Container(
      padding: const EdgeInsets.all(TtSpacing.l),
      decoration: const BoxDecoration(color: TtColors.coral50, borderRadius: TtRadii.cardRadius),
      child: Row(children: [
        const Icon(Symbols.savings_rounded, color: TtColors.coral600, fill: 1, size: 32),
        const SizedBox(width: TtSpacing.m),
        Expanded(
          child: Text(
              live
                  ? 'This month you saved ~${formatInr(monthSaved ?? 0)} in commission'
                  : 'Since joining, you saved ~${formatInr(Seed.lifetimeCommissionSaved)} in commission',
              style: TtTextStyles.tabular(t.bodySemibold)),
        ),
      ]),
    );

    final history = [
      const SectionLabel('Payment history'),
      TtCard(
        padding: EdgeInsets.zero,
        child: payments == null
            ? const Padding(
                padding: EdgeInsets.all(TtSpacing.l),
                child: SkeletonShimmer(child: SkeletonBox(height: 48)),
              )
            : Column(children: [
                for (var i = 0; i < payments.length; i++) ...[
                  if (i > 0) const Divider(),
                  _PaymentRow(record: payments[i], upiApp: plan.upiApp),
                ],
              ]),
      ),
    ];

    final List<Widget> content;
    final List<Widget> actions;
    switch (status) {
      case PlanStatus.paused:
        content = [
          const TtBanner(
            type: TtBannerType.info,
            title: "You can't go online while paused",
            message: 'No auto-debits until you resume.',
          ),
        ];
        actions = [
          TtButton(
            label: 'Resume plan',
            icon: Symbols.play_circle_rounded,
            onPressed: () => _run(context, notifier.resume, 'Plan resumed. You can go online.'),
          ),
          const SizedBox(height: TtSpacing.s),
          Center(child: TtButton(label: 'Cancel plan', variant: TtButtonVariant.dangerText, expand: false, onPressed: cancel)),
        ];
      case PlanStatus.cancelled:
        content = [
          TtBanner(
            type: TtBannerType.success,
            title: 'You can still go online until $end',
            message: 'Keep 100% of every fare till then.',
          ),
          const SizedBox(height: TtSpacing.m),
          savings,
        ];
        actions = [
          TtButton(
            label: 'Restart plan · $priceText/month',
            onPressed: () => _run(context, notifier.resume, 'Plan restarted. Auto-debit resumes on $end.'),
          ),
        ];
      case PlanStatus.grace || PlanStatus.expired:
        content = [
          TtBanner(
            type: status == PlanStatus.grace ? TtBannerType.warning : TtBannerType.error,
            title: status == PlanStatus.grace
                ? 'Payment failed. ${plan.graceDaysLeft} days left to renew.'
                : 'Plan expired. Renew to go online again',
            message: status == PlanStatus.grace ? 'You can still go online.' : 'Your ratings and documents are saved.',
          ),
          const SizedBox(height: TtSpacing.m),
          savings,
          ...history,
        ];
        actions = [
          TtButton(label: status == PlanStatus.grace ? 'Pay $priceText now' : 'Renew $priceText', onPressed: pay),
          const SizedBox(height: TtSpacing.s),
          TtButton.secondary(label: 'Change UPI app', onPressed: () => context.push(Routes.autopay(purpose: 'change'))),
        ];
      case PlanStatus.trial || PlanStatus.active:
        content = [savings, ...history];
        actions = [
          Row(children: [
            Expanded(
              child: TtButton.secondary(
                label: 'Change UPI app',
                onPressed: () => context.push(Routes.autopay(purpose: 'change')),
              ),
            ),
            const SizedBox(width: TtSpacing.m),
            Expanded(child: TtButton.secondary(label: 'Pause plan', onPressed: pause)),
          ]),
          const SizedBox(height: TtSpacing.s),
          Center(child: TtButton(label: 'Cancel plan', variant: TtButtonVariant.dangerText, expand: false, onPressed: cancel)),
        ];
    }

    return Scaffold(
      backgroundColor: TtColors.background,
      body: Column(children: [
        _header(t),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: TtSpacing.l),
            children: [
              // The status card overlaps the bottom of the navy header.
              Stack(children: [
                Container(height: 112, color: TtColors.navy900),
                Padding(padding: const EdgeInsets.symmetric(horizontal: TtSpacing.gutter), child: statusCard),
              ]),
              Padding(
                padding: const EdgeInsets.fromLTRB(TtSpacing.gutter, TtSpacing.l, TtSpacing.gutter, 0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  ...content,
                  const SizedBox(height: TtSpacing.xl),
                  ...actions,
                ]),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _header(TtTextStyles t) => NavyHeader(
        padding: const EdgeInsets.fromLTRB(TtSpacing.gutter, TtSpacing.l, TtSpacing.gutter, TtSpacing.l),
        child: Row(children: [
          Expanded(child: Text('Plan', style: t.display.copyWith(color: Colors.white))),
          const CommissionBadge(large: true),
        ]),
      );
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({required this.record, required this.upiApp});
  final PaymentRecord record;
  final String upiApp;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final (String sub, Widget trailing) = switch (record.status) {
      PaymentRecordStatus.freeTrial => (
          'Free trial',
          Text(formatInr(0), style: TtTextStyles.tabular(t.bodySemibold.copyWith(color: TtColors.successText))),
        ),
      PaymentRecordStatus.paid => (
          '$upiApp Autopay · ${formatShortDate(record.date).split(' ').reversed.join(' ')}',
          Row(mainAxisSize: MainAxisSize.min, children: [
            Text(formatInr(record.amount), style: TtTextStyles.tabular(t.bodySemibold)),
            const SizedBox(width: TtSpacing.m),
            const StatusPill(StatusKind.paid),
          ]),
        ),
      PaymentRecordStatus.failed => (
          'Payment failed',
          Row(mainAxisSize: MainAxisSize.min, children: [
            Text(formatInr(record.amount), style: TtTextStyles.tabular(t.bodySemibold)),
            const SizedBox(width: TtSpacing.m),
            const StatusPill(StatusKind.rejected, label: 'Failed'),
          ]),
        ),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: TtSpacing.l, vertical: TtSpacing.m),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(record.label, style: t.h2),
            Text(sub, style: t.bodySmall.copyWith(color: TtColors.navy500)),
          ]),
        ),
        trailing,
      ]),
    );
  }
}
