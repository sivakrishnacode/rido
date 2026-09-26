import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

/// Refer a driver sheet: the referral code "KARTHIK7", Copy, and WhatsApp / SMS share.
class ReferDriverSheet extends StatelessWidget {
  const ReferDriverSheet({super.key, this.showcase = false});

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  static Future<void> show(BuildContext context) =>
      showRidoSheet<void>(context, builder: (_) => const ReferDriverSheet());

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(const ClipboardData(text: Seed.referralCode));
    if (context.mounted) showRidoSnack(context, 'Code ${Seed.referralCode} copied', success: true);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      const SizedBox(height: RidoSpacing.s),
      Text('Refer a driver', style: t.h1),
      const SizedBox(height: RidoSpacing.xs),
      Text('Rido is free for drivers: 0% commission, no subscription. Invite the drivers you know.',
          style: t.body.copyWith(color: RidoColors.navy700)),
      const SizedBox(height: RidoSpacing.xl),
      Container(
        padding: const EdgeInsets.fromLTRB(RidoSpacing.l, RidoSpacing.m, RidoSpacing.s, RidoSpacing.m),
        decoration: BoxDecoration(
          color: RidoColors.coral50,
          borderRadius: RidoRadii.cardRadius,
          border: Border.all(color: RidoColors.coral100),
        ),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('YOUR CODE', style: t.overline),
              Text(Seed.referralCode, style: t.otp.copyWith(color: RidoColors.coral600, letterSpacing: 3)),
            ]),
          ),
          TextButton.icon(
            onPressed: () => _copy(context),
            icon: const Icon(Symbols.content_copy_rounded),
            label: const Text('Copy'),
          ),
        ]),
      ),
      const SizedBox(height: RidoSpacing.xl),
      Row(children: [
        Expanded(
          child: RidoButton(
            label: 'WhatsApp',
            icon: Symbols.chat_rounded,
            onPressed: () => showRidoSnack(context, 'Opening WhatsApp'),
          ),
        ),
        const SizedBox(width: RidoSpacing.m),
        Expanded(
          child: RidoButton.secondary(
            label: 'SMS',
            icon: Symbols.sms_rounded,
            onPressed: () => showRidoSnack(context, 'Opening Messages'),
          ),
        ),
      ]),
      const SizedBox(height: RidoSpacing.m),
      Text('Free days are added when your friend completes 10 rides.', style: t.caption, textAlign: TextAlign.center),
    ]);
  }
}
