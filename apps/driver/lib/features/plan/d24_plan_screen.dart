import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

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
      if (context.mounted) showRidoSnack(context, done, success: true);
    } on OfflineException {
      if (context.mounted) showRidoSnack(context, "You're offline. Try again.");
    } on ApiException catch (e) {
      if (context.mounted) showRidoSnack(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.type;
    final plan = ref.watch(planProvider).value;
    final payments = ref.watch(paymentsProvider).value;
    // Live API: the month's commission saved from the earnings endpoint (no lifetime figure yet).
    final live = !showcase && ref.watch(isLiveApiProvider);
    final monthSaved = live ? ref.watch(earningsProvider(EarningsPeriod.month)).value?.commissionSaved : null;
    final notifier = ref.read(planProvider.notifier);

    if (plan == null) {
      return Scaffold(
        backgroundColor: RidoColors.background,
        body: Column(children: [
          _header(t),
          const Expanded(
            child: SkeletonShimmer(
              child: Padding(
                padding: EdgeInsets.all(RidoSpacing.gutter),
                child: Column(children: [
                  SkeletonBox(height: 200, radius: RidoRadii.card),
                  SizedBox(height: RidoSpacing.m),
                  SkeletonBox(height: 80, radius: RidoRadii.card),
                  SizedBox(height: RidoSpacing.m),
                  SkeletonBox(height: 140, radius: RidoRadii.card),
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
      final ok = await showRidoConfirm(
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
      final ok = await showRidoConfirm(
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
      PlanStatus.expired => ('Plan expired on ${formatDate(RidoClock.today)}', 'Renew to go online'),
      PlanStatus.paused => ('Paused on ${formatDate(RidoClock.today)}', '30 trial days saved for later'),
      PlanStatus.cancelled => ('Cancelled, active till', end),
    };
    final statusCard = RidoCard(
      shadow: true,
      borderColor: null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('${plan.vehicle.label} plan', style: t.h1)),
          if (status == PlanStatus.trial) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: const BoxDecoration(color: RidoColors.coral50, borderRadius: RidoRadii.pillRadius),
              child: Text('Free trial', style: t.caption.copyWith(color: RidoColors.coral600, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: RidoSpacing.s),
          ],
          StatusPill(pillKind, label: pillLabel, large: true),
        ]),
        const SizedBox(height: RidoSpacing.l),
        Text(caption, style: t.body.copyWith(color: RidoColors.navy500)),
        Text(headline, style: RidoTextStyles.tabular(t.h1)),
        const SizedBox(height: RidoSpacing.l),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: RidoSpacing.l, vertical: RidoSpacing.m),
          decoration: const BoxDecoration(color: RidoColors.inputBg, borderRadius: RidoRadii.cardRadius),
          child: Row(children: [
            if (status == PlanStatus.cancelled)
              const Icon(Symbols.event_busy_rounded, color: RidoColors.navy700)
            else
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: RidoColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: RidoColors.divider),
                ),
                child: Text(plan.upiApp.substring(0, 1), style: t.caption.copyWith(fontWeight: FontWeight.w700, color: RidoColors.navy900)),
              ),
            const SizedBox(width: RidoSpacing.m),
            Expanded(
              child: Text(status == PlanStatus.cancelled ? 'No more auto-debits' : 'UPI Autopay: ${plan.upiApp}',
                  style: t.body),
            ),
            if (status == PlanStatus.paused)
              Text('Paused', style: t.bodySmallMedium.copyWith(color: RidoColors.navy500))
            else
              const Icon(Symbols.check_circle_rounded, color: RidoColors.success, fill: 1),
          ]),
        ),
      ]),
    );

    final savings = Container(
      padding: const EdgeInsets.all(RidoSpacing.l),
      decoration: const BoxDecoration(color: RidoColors.coral50, borderRadius: RidoRadii.cardRadius),
      child: Row(children: [
        const Icon(Symbols.savings_rounded, color: RidoColors.coral600, fill: 1, size: 32),
        const SizedBox(width: RidoSpacing.m),
        Expanded(
          child: Text(
              live
                  ? 'This month you saved ~${formatInr(monthSaved ?? 0)} in commission'
                  : 'Since joining, you saved ~${formatInr(Seed.lifetimeCommissionSaved)} in commission',
              style: RidoTextStyles.tabular(t.bodySemibold)),
        ),
      ]),
    );

    final history = [
      const SectionLabel('Payment history'),
      RidoCard(
        padding: EdgeInsets.zero,
        child: payments == null
            ? const Padding(
                padding: EdgeInsets.all(RidoSpacing.l),
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
          const RidoBanner(
            type: RidoBannerType.info,
            title: "You can't go online while paused",
            message: 'No auto-debits until you resume.',
          ),
        ];
        actions = [
          RidoButton(
            label: 'Resume plan',
            icon: Symbols.play_circle_rounded,
            onPressed: () => _run(context, notifier.resume, 'Plan resumed. You can go online.'),
          ),
          const SizedBox(height: RidoSpacing.s),
          Center(child: RidoButton(label: 'Cancel plan', variant: RidoButtonVariant.dangerText, expand: false, onPressed: cancel)),
        ];
      case PlanStatus.cancelled:
        content = [
          RidoBanner(
            type: RidoBannerType.success,
            title: 'You can still go online until $end',
            message: 'Keep 100% of every fare till then.',
          ),
          const SizedBox(height: RidoSpacing.m),
          savings,
        ];
        actions = [
          RidoButton(
            label: 'Restart plan · $priceText/month',
            onPressed: () => _run(context, notifier.resume, 'Plan restarted. Auto-debit resumes on $end.'),
          ),
        ];
      case PlanStatus.grace || PlanStatus.expired:
        content = [
          RidoBanner(
            type: status == PlanStatus.grace ? RidoBannerType.warning : RidoBannerType.error,
            title: status == PlanStatus.grace
                ? 'Payment failed. ${plan.graceDaysLeft} days left to renew.'
                : 'Plan expired. Renew to go online again',
            message: status == PlanStatus.grace ? 'You can still go online.' : 'Your ratings and documents are saved.',
          ),
          const SizedBox(height: RidoSpacing.m),
          savings,
          ...history,
        ];
        actions = [
          RidoButton(label: status == PlanStatus.grace ? 'Pay $priceText now' : 'Renew $priceText', onPressed: pay),
          const SizedBox(height: RidoSpacing.s),
          RidoButton.secondary(label: 'Change UPI app', onPressed: () => context.push(Routes.autopay(purpose: 'change'))),
        ];
      case PlanStatus.trial || PlanStatus.active:
        content = [savings, ...history];
        actions = [
          Row(children: [
            Expanded(
              child: RidoButton.secondary(
                label: 'Change UPI app',
                onPressed: () => context.push(Routes.autopay(purpose: 'change')),
              ),
            ),
            const SizedBox(width: RidoSpacing.m),
            Expanded(child: RidoButton.secondary(label: 'Pause plan', onPressed: pause)),
          ]),
          const SizedBox(height: RidoSpacing.s),
          Center(child: RidoButton(label: 'Cancel plan', variant: RidoButtonVariant.dangerText, expand: false, onPressed: cancel)),
        ];
    }

    return Scaffold(
      backgroundColor: RidoColors.background,
      body: Column(children: [
        _header(t),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: RidoSpacing.l),
            children: [
              // The status card overlaps the bottom of the navy header.
              Stack(children: [
                Container(height: 112, color: RidoColors.navy900),
                Padding(padding: const EdgeInsets.symmetric(horizontal: RidoSpacing.gutter), child: statusCard),
              ]),
              Padding(
                padding: const EdgeInsets.fromLTRB(RidoSpacing.gutter, RidoSpacing.l, RidoSpacing.gutter, 0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  ...content,
                  const SizedBox(height: RidoSpacing.xl),
                  ...actions,
                ]),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _header(RidoTextStyles t) => NavyHeader(
        padding: const EdgeInsets.fromLTRB(RidoSpacing.gutter, RidoSpacing.l, RidoSpacing.gutter, RidoSpacing.l),
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
          Text(formatInr(0), style: RidoTextStyles.tabular(t.bodySemibold.copyWith(color: RidoColors.successText))),
        ),
      PaymentRecordStatus.paid => (
          '$upiApp Autopay · ${formatShortDate(record.date).split(' ').reversed.join(' ')}',
          Row(mainAxisSize: MainAxisSize.min, children: [
            Text(formatInr(record.amount), style: RidoTextStyles.tabular(t.bodySemibold)),
            const SizedBox(width: RidoSpacing.m),
            const StatusPill(StatusKind.paid),
          ]),
        ),
      PaymentRecordStatus.failed => (
          'Payment failed',
          Row(mainAxisSize: MainAxisSize.min, children: [
            Text(formatInr(record.amount), style: RidoTextStyles.tabular(t.bodySemibold)),
            const SizedBox(width: RidoSpacing.m),
            const StatusPill(StatusKind.rejected, label: 'Failed'),
          ]),
        ),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: RidoSpacing.l, vertical: RidoSpacing.m),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(record.label, style: t.h2),
            Text(sub, style: t.bodySmall.copyWith(color: RidoColors.navy500)),
          ]),
        ),
        trailing,
      ]),
    );
  }
}
