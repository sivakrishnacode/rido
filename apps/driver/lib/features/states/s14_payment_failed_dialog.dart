import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';
import 'package:tamiltaxi_ui/tamiltaxi_ui.dart';

import '../../state/driver_account.dart';

/// S-14 Autopay payment failed (amber dialog). Pops `'retry'` ("Retry with another UPI app")
/// or `'later'` ("Pay later", 2-day grace).
class S14PaymentFailedDialog extends ConsumerWidget {
  const S14PaymentFailedDialog({super.key, this.showcase = false});

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  /// Shows the dialog; resolves to `'retry'`, `'later'` or null (dismissed).
  static Future<String?> show(BuildContext context) =>
      showDialog<String>(context: context, builder: (_) => const S14PaymentFailedDialog());

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.type;
    final plan = showcase ? Seed.plan() : (ref.watch(planProvider).value ?? Seed.plan());
    final amount = formatInr(plan.monthlyPrice ?? 2000);
    final days = plan.graceDaysLeft;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(height: 6, color: TtColors.warning),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(color: TtColors.warningTint, shape: BoxShape.circle),
                      child: const Icon(Symbols.credit_card_off_rounded,
                          color: TtColors.warningText, fill: 1, size: 32, semanticLabel: 'Payment failed'),
                    ),
                  ),
                  const SizedBox(height: TtSpacing.l),
                  Text("Your $amount payment didn't go through", style: TtTextStyles.tabular(t.h1)),
                  const SizedBox(height: TtSpacing.s),
                  Text(
                    '${plan.upiApp} declined the Autopay debit. You can still go online for $days days.',
                    style: t.body.copyWith(color: TtColors.navy700),
                  ),
                  const SizedBox(height: TtSpacing.l),
                  TtButton(
                    label: 'Retry with another UPI app',
                    onPressed: () => Navigator.of(context).pop('retry'),
                  ),
                  const SizedBox(height: TtSpacing.xs),
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: TtColors.navy900,
                      minimumSize: const Size.fromHeight(48),
                      textStyle: t.button,
                    ),
                    onPressed: () => Navigator.of(context).pop('later'),
                    child: Text('Pay later ($days days left)'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
