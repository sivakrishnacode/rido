import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';
import 'package:tamiltaxi_ui/tamiltaxi_ui.dart';

/// Refer a driver sheet: the referral code "KARTHIK7", Copy, and WhatsApp / SMS share.
class ReferDriverSheet extends StatelessWidget {
  const ReferDriverSheet({super.key, this.showcase = false});

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  static Future<void> show(BuildContext context) =>
      showTtSheet<void>(context, builder: (_) => const ReferDriverSheet());

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(const ClipboardData(text: Seed.referralCode));
    if (context.mounted) showTtSnack(context, 'Code ${Seed.referralCode} copied', success: true);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      const SizedBox(height: TtSpacing.s),
      Text('Refer a driver', style: t.h1),
      const SizedBox(height: TtSpacing.xs),
      Text('Tamil Taxi is free for drivers: 0% commission, no subscription. Invite the drivers you know.',
          style: t.body.copyWith(color: TtColors.navy700)),
      const SizedBox(height: TtSpacing.xl),
      Container(
        padding: const EdgeInsets.fromLTRB(TtSpacing.l, TtSpacing.m, TtSpacing.s, TtSpacing.m),
        decoration: BoxDecoration(
          color: TtColors.coral50,
          borderRadius: TtRadii.cardRadius,
          border: Border.all(color: TtColors.coral100),
        ),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('YOUR CODE', style: t.overline),
              Text(Seed.referralCode, style: t.otp.copyWith(color: TtColors.coral600, letterSpacing: 3)),
            ]),
          ),
          TextButton.icon(
            onPressed: () => _copy(context),
            icon: const Icon(Symbols.content_copy_rounded),
            label: const Text('Copy'),
          ),
        ]),
      ),
      const SizedBox(height: TtSpacing.xl),
      Row(children: [
        Expanded(
          child: TtButton(
            label: 'WhatsApp',
            icon: Symbols.chat_rounded,
            onPressed: () => showTtSnack(context, 'Opening WhatsApp'),
          ),
        ),
        const SizedBox(width: TtSpacing.m),
        Expanded(
          child: TtButton.secondary(
            label: 'SMS',
            icon: Symbols.sms_rounded,
            onPressed: () => showTtSnack(context, 'Opening Messages'),
          ),
        ),
      ]),
      const SizedBox(height: TtSpacing.m),
      Text('Free days are added when your friend completes 10 rides.', style: t.caption, textAlign: TextAlign.center),
    ]);
  }
}
