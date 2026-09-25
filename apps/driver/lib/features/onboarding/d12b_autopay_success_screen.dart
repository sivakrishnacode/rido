import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

import '../../router/routes.dart';
import '../../state/driver_account.dart';
import '../../state/driver_session.dart';
import 'widgets/signup_widgets.dart';

/// D-12b Autopay success: "You're all set!", the trial (setup) or payment (pay) status, the
/// plan summary and "Go online" → Home, already online (D-14).
class D12bAutopaySuccessScreen extends ConsumerWidget {
  const D12bAutopaySuccessScreen({super.key, this.purpose = 'setup', this.showcase = false});

  final String purpose;

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.type;
    final pay = purpose == 'pay';
    final plan = showcase ? Seed.plan() : (ref.watch(planProvider).value ?? Seed.plan());
    final upi = showcase ? Seed.karthik.upiId : (ref.watch(driverProfileProvider).value?.upiId ?? Seed.karthik.upiId);
    final daysLeft = plan.nextDebit.difference(RidoClock.today).inDays;
    final price = plan.monthlyPrice == null ? '₹—' : formatInr(plan.monthlyPrice!);
    final vehicle = plan.vehicle == VehicleKind.truck ? 'Truck' : plan.vehicle.label;
    final date = formatDate(plan.nextDebit);

    void goOnline() {
      final s = ref.read(driverSessionProvider.notifier);
      s.markSelfieDone();
      s.goOnline();
      context.go(Routes.home);
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) context.go(Routes.home);
        },
        child: Scaffold(
          backgroundColor: RidoColors.surface,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                color: RidoColors.navy900,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(RidoSpacing.l, RidoSpacing.xxl, RidoSpacing.l, RidoSpacing.xl),
                    child: Column(
                      children: [
                        Semantics(
                          image: true,
                          label: 'Success',
                          child: const DriverOrb(
                            size: 160,
                            color: RidoColors.success,
                            dots: true,
                            child: Icon(Symbols.check_rounded, color: Colors.white, size: 72, weight: 600),
                          ),
                        ),
                        const SizedBox(height: RidoSpacing.xl),
                        Text("You're all set!", textAlign: TextAlign.center, style: t.display.copyWith(color: Colors.white)),
                        const SizedBox(height: RidoSpacing.m),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: pay ? RidoColors.successTint : RidoColors.coral50,
                            borderRadius: RidoRadii.pillRadius,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(pay ? Symbols.check_circle_rounded : Symbols.redeem_rounded,
                                  size: 20,
                                  fill: pay ? 1 : 0,
                                  color: pay ? RidoColors.successText : RidoColors.coral600),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  pay ? 'Payment received. Plan active till $date' : 'Free trial active: $daysLeft days left',
                                  textAlign: TextAlign.center,
                                  style: t.bodySemibold.copyWith(color: pay ? RidoColors.successText : RidoColors.coral600),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(RidoSpacing.l),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(RidoSpacing.l),
                        decoration: BoxDecoration(
                          color: RidoColors.surface,
                          borderRadius: RidoRadii.cardRadius,
                          border: Border.all(color: RidoColors.divider),
                        ),
                        child: Column(
                          children: [
                            _row(t, 'Plan', Text('$vehicle · $price/month', style: _v(t), textAlign: TextAlign.right)),
                            _row(t, pay ? 'Next charge' : 'First charge',
                                Text('$date · via ${plan.upiApp}', style: _v(t), textAlign: TextAlign.right)),
                            _row(t, 'Commission', const Align(alignment: Alignment.centerRight, child: CommissionBadge(large: true))),
                          ],
                        ),
                      ),
                      const SizedBox(height: RidoSpacing.l),
                      Text('Riders will pay you directly by cash or UPI to $upi.',
                          style: t.bodySmall.copyWith(color: RidoColors.navy700)),
                    ],
                  ),
                ),
              ),
              BottomActions(
                children: [RidoButton(label: 'Go online', icon: Symbols.power_settings_new_rounded, onPressed: goOnline)],
              ),
            ],
          ),
        ),
      ),
    );
  }

  TextStyle _v(RidoTextStyles t) => RidoTextStyles.tabular(t.bodyMedium.copyWith(fontWeight: FontWeight.w600));

  Widget _row(RidoTextStyles t, String k, Widget v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Text(k, style: t.body.copyWith(color: RidoColors.navy700)),
            const SizedBox(width: RidoSpacing.m),
            Expanded(child: v),
          ],
        ),
      );
}
