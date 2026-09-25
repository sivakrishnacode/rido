import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

import '../../router/routes.dart';
import '../../state/driver_account.dart';
import 'widgets/signup_widgets.dart';

/// D-11 Choose plan and start the free trial: plan card, benefits, the commission
/// comparison and "Set up UPI Autopay" → D-12.
class D11ChoosePlanScreen extends ConsumerWidget {
  const D11ChoosePlanScreen({super.key, this.showcase = false});

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  static const _fares = 35000;
  static const _commission = 10500;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.type;
    final signup = ref.watch(signupProvider);
    final plan = showcase ? Seed.plan() : (ref.watch(planProvider).value ?? Seed.plan(vehicle: signup.vehicle));
    final name = showcase ? Seed.karthik.firstName : (ref.watch(driverProfileProvider).value?.firstName ?? 'Karthik');
    final price = plan.monthlyPrice;
    final priceText = price == null ? '₹—' : formatInr(price);
    final vehicleName = plan.vehicle == VehicleKind.truck ? 'Truck' : plan.vehicle.label;
    final deliveries = plan.vehicle.isGoods;

    return Scaffold(
      backgroundColor: RidoColors.background,
      appBar: SignupAppBar(title: 'Your plan', step: 6, onBack: backOr(context, Routes.documents)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Stack(
                children: [
                  Container(height: 150, color: RidoColors.navy900),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(RidoSpacing.l, RidoSpacing.xs, RidoSpacing.l, RidoSpacing.l),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Icon(Symbols.verified_rounded, color: RidoColors.success, fill: 1, size: 22),
                            const SizedBox(width: 6),
                            Text('Documents approved',
                                style: t.bodySemibold.copyWith(color: RidoColors.success)),
                          ],
                        ),
                        const SizedBox(height: RidoSpacing.xs),
                        Text('Start earning, $name', style: t.display.copyWith(color: Colors.white)),
                        const SizedBox(height: RidoSpacing.l),
                        _planCard(context, vehicleName, priceText, deliveries, plan.vehicle),
                        const SizedBox(height: RidoSpacing.l),
                        _comparison(context, priceText, price),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          BottomActions(
            children: [
              RidoButton(label: 'Set up UPI Autopay', onPressed: () => context.push(Routes.autopay(purpose: 'setup'))),
              const SizedBox(height: RidoSpacing.s),
              Text(
                price == null
                    ? "₹0 today. We'll call you to confirm your plan price. Cancel anytime."
                    : '₹0 today. $priceText auto-debits on ${formatDate(plan.nextDebit)}. Cancel anytime.',
                textAlign: TextAlign.center,
                style: RidoTextStyles.tabular(t.caption.copyWith(color: RidoColors.navy700)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _planCard(BuildContext context, String vehicleName, String priceText, bool deliveries, VehicleKind kind) {
    final t = context.type;
    return Container(
      padding: const EdgeInsets.all(RidoSpacing.l),
      decoration: const BoxDecoration(
        color: RidoColors.surface,
        borderRadius: BorderRadius.all(Radius.circular(RidoRadii.sheet)),
        boxShadow: RidoShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 64,
                height: 56,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: RidoColors.coral50, borderRadius: RidoRadii.cardRadius),
                child: VehicleArt(kind, size: 32),
              ),
              const SizedBox(width: RidoSpacing.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$vehicleName plan', style: t.h2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(priceText, style: t.otp),
                          const SizedBox(width: 4),
                          Text('/ month', style: t.body.copyWith(color: RidoColors.navy500)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: RidoSpacing.l),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: RidoSpacing.l, vertical: RidoSpacing.s),
            decoration: const BoxDecoration(color: RidoColors.coral600, borderRadius: RidoRadii.cardRadius),
            child: Row(
              children: [
                const Icon(Symbols.redeem_rounded, color: Colors.white, size: 22),
                const SizedBox(width: RidoSpacing.s),
                Flexible(child: Text('First month FREE', style: t.bodySemibold.copyWith(color: Colors.white))),
              ],
            ),
          ),
          const SizedBox(height: RidoSpacing.s),
          for (final b in [
            deliveries ? 'Unlimited deliveries' : 'Unlimited rides',
            'Keep 100% of fares',
            '0% commission',
            'Cancel anytime · 2-day grace if a payment is missed',
          ])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  const Icon(Symbols.check_rounded, color: RidoColors.success, size: 22, weight: 600),
                  const SizedBox(width: RidoSpacing.m),
                  Expanded(child: Text(b, style: t.body)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _comparison(BuildContext context, String priceText, int? price) {
    final t = context.type;
    final bold = t.bodySmall.copyWith(fontWeight: FontWeight.w700, color: RidoColors.navy900);
    final ridoShare = ((price ?? 0) / _commission).clamp(0.04, 1.0);
    Widget bar(String label, double f, Color color, String amount, {bool strong = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              SizedBox(
                width: 120,
                child: Text(label,
                    style: t.bodySmall.copyWith(
                        color: strong ? RidoColors.navy900 : RidoColors.navy500,
                        fontWeight: strong ? FontWeight.w600 : null)),
              ),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: FractionallySizedBox(
                        widthFactor: f,
                        alignment: Alignment.centerLeft,
                        child: Container(
                          height: 14,
                          decoration: BoxDecoration(color: color, borderRadius: RidoRadii.pillRadius),
                        ),
                      ),
                    ),
                    const SizedBox(width: RidoSpacing.s),
                    Flexible(
                      flex: 0,
                      child: Text(amount,
                        maxLines: 1,
                        style: RidoTextStyles.tabular(t.bodySmallMedium.copyWith(
                            color: strong ? RidoColors.coral600 : RidoColors.navy900, fontWeight: FontWeight.w700))),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
    return Container(
      padding: const EdgeInsets.all(RidoSpacing.l),
      decoration: BoxDecoration(
        color: RidoColors.surface,
        borderRadius: RidoRadii.cardRadius,
        border: Border.all(color: RidoColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text.rich(
            TextSpan(
              style: RidoTextStyles.tabular(t.bodySmall.copyWith(color: RidoColors.navy700)),
              children: [
                const TextSpan(text: 'On a commission app, '),
                TextSpan(text: formatInr(_fares), style: bold),
                const TextSpan(text: ' in fares costs you '),
                TextSpan(text: '~${formatInr(_commission)}', style: bold),
                const TextSpan(text: '. On Rido: '),
                TextSpan(text: priceText, style: bold.copyWith(color: RidoColors.coral600)),
                const TextSpan(text: '.'),
              ],
            ),
          ),
          const SizedBox(height: RidoSpacing.m),
          bar('Commission app', 1, RidoColors.navy500, formatInr(_commission)),
          bar('Rido', ridoShare, RidoColors.coral500, priceText, strong: true),
          const SizedBox(height: RidoSpacing.s),
          Text('Assumes 30% commission on ${formatInr(_fares)} monthly fares.',
              style: t.caption.copyWith(color: RidoColors.navy500)),
        ],
      ),
    );
  }
}
