import 'package:flutter/material.dart';
import 'package:tamiltaxi_ui/tamiltaxi_ui.dart';

import '../../common/launch.dart';

/// The driver app on Google Play.
const kDriverAppLink = 'https://play.google.com/store/apps/details?id=com.tamiltaxi.driver';

/// What an invite says (WhatsApp or SMS).
const kDriverInviteText = 'I drive with Tamil Taxi: 0% commission and no subscription, so you keep the whole fare. '
    'Get the Tamil Taxi Driver app: $kDriverAppLink';

/// Refer a driver: a plain invite to the app (no code, no reward: the app is free for everyone), shown as it will
/// be sent, with WhatsApp and SMS.
class ReferDriverSheet extends StatelessWidget {
  const ReferDriverSheet({super.key, this.showcase = false});

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  static Future<void> show(BuildContext context, {bool showcase = false}) =>
      showTtSheet<void>(context, builder: (_) => ReferDriverSheet(showcase: showcase));

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    void preview() => showTtSnack(context, 'Design preview: nothing is sent');
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      const SizedBox(height: TtSpacing.s),
      Text('Refer a driver', style: t.h1),
      const SizedBox(height: TtSpacing.xs),
      Text('Tamil Taxi is free for drivers: 0% commission, no subscription. Invite the drivers you know.',
          style: t.body.copyWith(color: TtColors.navy700)),
      const SizedBox(height: TtSpacing.l),
      Text('YOUR MESSAGE', style: t.overline),
      const SizedBox(height: TtSpacing.s),
      Container(
        padding: const EdgeInsets.all(TtSpacing.l),
        decoration: BoxDecoration(
          color: TtColors.coral50,
          borderRadius: TtRadii.cardRadius,
          border: Border.all(color: TtColors.coral100),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Symbols.format_quote_rounded, color: TtColors.coral600, fill: 1),
          const SizedBox(width: TtSpacing.s),
          Expanded(child: Text(kDriverInviteText, style: t.bodySmall.copyWith(color: TtColors.navy900))),
        ]),
      ),
      const SizedBox(height: TtSpacing.xl),
      Row(children: [
        Expanded(
          child: TtButton(
            label: 'WhatsApp',
            icon: Symbols.chat_rounded,
            onPressed: showcase ? preview : () => shareOnWhatsApp(context, kDriverInviteText),
          ),
        ),
        const SizedBox(width: TtSpacing.m),
        Expanded(
          child: TtButton.secondary(
            label: 'SMS',
            icon: Symbols.sms_rounded,
            onPressed: showcase ? preview : () => shareBySms(context, kDriverInviteText),
          ),
        ),
      ]),
      const SizedBox(height: TtSpacing.s),
    ]);
  }
}
