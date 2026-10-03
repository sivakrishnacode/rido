import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';
import 'package:tamiltaxi_ui/tamiltaxi_ui.dart';

import '../../common/showcase.dart';
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
    final name = showcase ? Seed.karthik.firstName : (ref.watch(driverProfileProvider).value?.firstName ?? '');
    final price = plan.monthlyPrice;
    final priceText = price == null ? '₹—' : formatInr(price);
    final vehicleName = plan.vehicle == VehicleKind.truck ? 'Truck' : plan.vehicle.label;
    final deliveries = plan.vehicle.isGoods;

    return Scaffold(
      backgroundColor: TtColors.background,
      appBar: SignupAppBar(title: 'Your plan', onBack: backOr(context, Routes.home)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Stack(
                children: [
                  Container(height: 150, color: TtColors.navy900),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(TtSpacing.l, TtSpacing.xs, TtSpacing.l, TtSpacing.l),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Icon(Symbols.verified_rounded, color: TtColors.success, fill: 1, size: 22),
                            const SizedBox(width: 6),
                            Text('Documents approved',
                                style: t.bodySemibold.copyWith(color: TtColors.success)),
                          ],
                        ),
                        const SizedBox(height: TtSpacing.xs),
                        Text(name.isEmpty ? 'Start earning' : 'Start earning, $name', style: t.display.copyWith(color: Colors.white)),
                        const SizedBox(height: TtSpacing.l),
                        _planCard(context, vehicleName, priceText, deliveries, plan.vehicle),
                        const SizedBox(height: TtSpacing.l),
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
              TtButton(
                  label: 'Set up UPI Autopay',
                  onPressed: unlessShowcase(context, showcase, () => context.push(Routes.autopay(purpose: 'setup')))),
              const SizedBox(height: TtSpacing.s),
              Text(
                price == null
                    ? "₹0 today. We'll call you to confirm your plan price. Cancel anytime."
                    : '₹0 today. $priceText auto-debits on ${formatDate(plan.nextDebit)}. Cancel anytime.',
                textAlign: TextAlign.center,
                style: TtTextStyles.tabular(t.caption.copyWith(color: TtColors.navy700)),
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
      padding: const EdgeInsets.all(TtSpacing.l),
      decoration: const BoxDecoration(
        color: TtColors.surface,
        borderRadius: BorderRadius.all(Radius.circular(TtRadii.sheet)),
        boxShadow: TtShadows.soft,
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
                decoration: const BoxDecoration(color: TtColors.coral50, borderRadius: TtRadii.cardRadius),
                child: VehicleArt(kind, width: 48, height: 34),
              ),
              const SizedBox(width: TtSpacing.m),
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
                          Text('/ month', style: t.body.copyWith(color: TtColors.navy500)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: TtSpacing.l),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: TtSpacing.l, vertical: TtSpacing.s),
            decoration: const BoxDecoration(color: TtColors.coral600, borderRadius: TtRadii.cardRadius),
            child: Row(
              children: [
                const Icon(Symbols.redeem_rounded, color: Colors.white, size: 22),
                const SizedBox(width: TtSpacing.s),
                Flexible(child: Text('First month FREE', style: t.bodySemibold.copyWith(color: Colors.white))),
              ],
            ),
          ),
          const SizedBox(height: TtSpacing.s),
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
                  const Icon(Symbols.check_rounded, color: TtColors.success, size: 22, weight: 600),
                  const SizedBox(width: TtSpacing.m),
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
    final bold = t.bodySmall.copyWith(fontWeight: FontWeight.w700, color: TtColors.navy900);
    final ttShare = ((price ?? 0) / _commission).clamp(0.04, 1.0);
    Widget bar(String label, double f, Color color, String amount, {bool strong = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              SizedBox(
                width: 120,
                child: Text(label,
                    style: t.bodySmall.copyWith(
                        color: strong ? TtColors.navy900 : TtColors.navy500,
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
                          decoration: BoxDecoration(color: color, borderRadius: TtRadii.pillRadius),
                        ),
                      ),
                    ),
                    const SizedBox(width: TtSpacing.s),
                    Flexible(
                      flex: 0,
                      child: Text(amount,
                        maxLines: 1,
                        style: TtTextStyles.tabular(t.bodySmallMedium.copyWith(
                            color: strong ? TtColors.coral600 : TtColors.navy900, fontWeight: FontWeight.w700))),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
    return Container(
      padding: const EdgeInsets.all(TtSpacing.l),
      decoration: BoxDecoration(
        color: TtColors.surface,
        borderRadius: TtRadii.cardRadius,
        border: Border.all(color: TtColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text.rich(
            TextSpan(
              style: TtTextStyles.tabular(t.bodySmall.copyWith(color: TtColors.navy700)),
              children: [
                const TextSpan(text: 'On a commission app, '),
                TextSpan(text: formatInr(_fares), style: bold),
                const TextSpan(text: ' in fares costs you '),
                TextSpan(text: '~${formatInr(_commission)}', style: bold),
                const TextSpan(text: '. On Tamil Taxi: '),
                TextSpan(text: priceText, style: bold.copyWith(color: TtColors.coral600)),
                const TextSpan(text: '.'),
              ],
            ),
          ),
          const SizedBox(height: TtSpacing.m),
          bar('Commission app', 1, TtColors.navy500, formatInr(_commission)),
          bar('Tamil Taxi', ttShare, TtColors.coral500, priceText, strong: true),
          const SizedBox(height: TtSpacing.s),
          Text('Assumes 30% commission on ${formatInr(_fares)} monthly fares.',
              style: t.caption.copyWith(color: TtColors.navy500)),
        ],
      ),
    );
  }
}
