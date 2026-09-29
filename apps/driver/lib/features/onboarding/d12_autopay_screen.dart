import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';
import 'package:tamiltaxi_ui/tamiltaxi_ui.dart';

import '../../router/routes.dart';
import '../../state/driver_account.dart';
import '../states/s14_payment_failed_dialog.dart';
import 'widgets/signup_widgets.dart';

/// D-12a UPI Autopay: pick a UPI app and approve. [purpose]: `setup` (D-11 → D-12b),
/// `change` (D-24: moves the mandate and goes back) or `pay` (D-25 / S-14: pays now;
/// a failed payment shows S-14).
class D12AutopayScreen extends ConsumerStatefulWidget {
  const D12AutopayScreen({super.key, this.purpose = 'setup', this.showcase = false});

  final String purpose;

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  @override
  ConsumerState<D12AutopayScreen> createState() => _D12AutopayScreenState();
}

class _D12AutopayScreenState extends ConsumerState<D12AutopayScreen> {
  String? _app = Seed.upiApps.first;
  bool _processing = false;
  Timer? _timer;

  bool get _pay => widget.purpose == 'pay';
  bool get _change => widget.purpose == 'change';

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Waits for the simulated UPI approval; never completes if the screen is disposed.
  Future<void> _wait() {
    final c = Completer<void>();
    _timer = Timer(ref.read(simTimingProvider)(SimTimings.upiProcessing), c.complete);
    return c.future;
  }

  Future<void> _approve() async {
    final app = _app;
    if (app == null || _processing) return;
    setState(() => _processing = true);
    await _wait();
    if (!mounted) return;
    final plan = ref.read(planProvider.notifier);
    try {
      if (_pay) {
        await plan.payNow(app);
        if (!mounted) return;
        context.go(Routes.autopaySuccess(purpose: 'pay'));
      } else {
        await plan.setupAutopay(app);
        if (!mounted) return;
        if (_change) {
          showTtSnack(context, 'Autopay moved to $app', success: true);
          Navigator.of(context).maybePop();
        } else {
          context.go(Routes.autopaySuccess(purpose: 'setup'));
        }
      }
    } on PaymentFailedException {
      if (!mounted) return;
      setState(() => _processing = false);
      final choice = await S14PaymentFailedDialog.show(context);
      if (!mounted) return;
      if (choice == 'retry') {
        setState(() => _app = null);
      } else if (choice == 'later') {
        await ref.read(planProvider.notifier).payLater();
        if (!mounted) return;
        showTtSnack(context, 'Pay within 2 days to keep going online');
        context.go(Routes.home);
      }
    } on OfflineException {
      if (!mounted) return;
      setState(() => _processing = false);
      showTtSnack(context, "You're offline. Check your connection and try again.");
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _processing = false);
      showTtSnack(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final plan = widget.showcase ? Seed.plan() : (ref.watch(planProvider).value ?? Seed.plan());
    final amount = formatInr(plan.monthlyPrice ?? 2000);
    final title = _pay ? 'Pay $amount now' : (_change ? 'Change UPI app' : 'Set up UPI Autopay');
    return PopScope(
      canPop: !_processing,
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: TtColors.surface,
            appBar: SignupAppBar(title: title),
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(TtSpacing.l),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _summary(t, plan, amount),
                        SectionLabel(_pay ? 'Pay with' : 'Approve with',
                            padding: const EdgeInsets.fromLTRB(0, 24, 0, 10)),
                        Container(
                          decoration: BoxDecoration(
                            color: TtColors.surface,
                            borderRadius: TtRadii.cardRadius,
                            border: Border.all(color: TtColors.divider),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            children: [
                              for (var i = 0; i < Seed.upiApps.length; i++) ...[
                                if (i > 0) const Divider(height: 1),
                                _AppRow(
                                  app: Seed.upiApps[i],
                                  selected: _app == Seed.upiApps[i],
                                  onTap: () => setState(() => _app = Seed.upiApps[i]),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: TtSpacing.l),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Symbols.lock_rounded, size: 18, color: TtColors.navy500),
                            const SizedBox(width: TtSpacing.s),
                            Expanded(
                              child: Text(
                                _pay
                                    ? "You'll approve this one-time payment in your UPI app with your UPI PIN."
                                    : "You'll approve in your UPI app with your UPI PIN. Pause or cancel anytime from Plan.",
                                style: t.bodySmall.copyWith(color: TtColors.navy500),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                BottomActions(
                  children: [
                    TtButton(
                      label: _app == null ? 'Choose a UPI app' : (_pay ? 'Pay $amount in $_app' : 'Approve in $_app'),
                      loading: _processing,
                      onPressed: _app == null ? null : _approve,
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_processing) _ProcessingOverlay(app: _app ?? ''),
        ],
      ),
    );
  }

  Widget _summary(TtTextStyles t, SubscriptionPlan plan, String amount) {
    Widget row(String k, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              Text(k, style: t.body.copyWith(color: TtColors.navy700)),
              const SizedBox(width: TtSpacing.m),
              Expanded(
                child: Text(v,
                    textAlign: TextAlign.right,
                    style: TtTextStyles.tabular(t.bodyMedium.copyWith(fontWeight: FontWeight.w600))),
              ),
            ],
          ),
        );
    final date = formatDate(plan.nextDebit);
    return Container(
      padding: const EdgeInsets.all(TtSpacing.l),
      decoration: BoxDecoration(
        color: TtColors.coral50,
        borderRadius: TtRadii.cardRadius,
        border: Border.all(color: TtColors.coral100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          row(_pay ? 'Plan' : 'Mandate', 'Tamil Taxi Driver Plan'),
          row('Amount', _pay ? '$amount · 1 month' : '$amount monthly'),
          row(_pay ? 'Active till' : (_change ? 'Next debit' : 'Starts'), date),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: TtSpacing.s),
            child: Divider(height: 1, color: TtColors.coral100),
          ),
          Row(
            children: [
              Expanded(child: Text(_pay ? 'Pay now' : 'Charged today', style: t.bodySemibold)),
              Text(_pay ? amount : '₹0',
                  style: t.otp.copyWith(color: _pay ? TtColors.navy900 : TtColors.successText)),
            ],
          ),
        ],
      ),
    );
  }
}

class _AppRow extends StatelessWidget {
  const _AppRow({required this.app, required this.selected, required this.onTap});

  final String app;
  final bool selected;
  final VoidCallback onTap;

  String get _mono => switch (app) {
        'GPay' => 'G',
        'PhonePe' => 'Pe',
        'Paytm' => 'Pa',
        'BHIM' => 'B',
        _ => app.substring(0, 1),
      };

  @override
  Widget build(BuildContext context) => Semantics(
        selected: selected,
        button: true,
        label: app,
        excludeSemantics: true,
        child: Material(
          color: selected ? TtColors.coral50 : TtColors.surface,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: TtSpacing.l, vertical: TtSpacing.m),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: TtColors.inputBg,
                      borderRadius: TtRadii.cardRadius,
                      border: Border.all(color: TtColors.divider),
                    ),
                    child: Text(_mono, style: context.type.bodySmallMedium.copyWith(fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: TtSpacing.m),
                  Expanded(child: Text(app, style: context.type.bodyMedium)),
                  Icon(
                    selected ? Symbols.radio_button_checked_rounded : Symbols.radio_button_unchecked_rounded,
                    color: selected ? TtColors.coral600 : TtColors.navy500,
                    size: 26,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class _ProcessingOverlay extends StatelessWidget {
  const _ProcessingOverlay({required this.app});
  final String app;

  @override
  Widget build(BuildContext context) => Positioned.fill(
        child: ColoredBox(
          color: TtColors.scrim,
          child: Center(
            child: Container(
              margin: const EdgeInsets.all(TtSpacing.xl),
              padding: const EdgeInsets.all(TtSpacing.xl),
              decoration: const BoxDecoration(
                color: TtColors.surface,
                borderRadius: BorderRadius.all(Radius.circular(TtRadii.sheet)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(color: TtColors.coral600, strokeWidth: 3),
                  ),
                  const SizedBox(height: TtSpacing.l),
                  Text('Waiting for approval in $app…', textAlign: TextAlign.center, style: context.type.bodySemibold),
                  const SizedBox(height: TtSpacing.xs),
                  Text('Enter your UPI PIN in the $app app',
                      textAlign: TextAlign.center,
                      style: context.type.bodySmall.copyWith(color: TtColors.navy500)),
                ],
              ),
            ),
          ),
        ),
      );
}
