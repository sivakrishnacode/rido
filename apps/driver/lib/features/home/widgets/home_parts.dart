import 'package:flutter/material.dart';
import 'package:rido_ui/rido_ui.dart';

import 'navy_header.dart';

/// D-13 / D-14 navy header: avatar, greeting, status pill and the "0% commission" badge.
class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.initials,
    required this.firstName,
    required this.subtitle,
    required this.pill,
    required this.onlineRing,
    required this.showBadge,
  });

  final String initials;
  final String firstName;
  final String subtitle;
  final Widget pill;
  final bool onlineRing;
  final bool showBadge;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return NavyHeader(
      padding: const EdgeInsets.fromLTRB(RidoSpacing.gutter, RidoSpacing.m, RidoSpacing.gutter, RidoSpacing.m),
      child: Row(
        children: [
          RidoAvatar(
            initials: initials,
            size: 46,
            tone: AvatarTone.dark,
            ringColor: onlineRing ? RidoColors.success : null,
          ),
          const SizedBox(width: RidoSpacing.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(subtitle,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodySmall.copyWith(color: Colors.white70)),
                Text('Hi, $firstName',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: t.h1.copyWith(color: Colors.white)),
              ],
            ),
          ),
          const SizedBox(width: RidoSpacing.s),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              pill,
              if (showBadge) ...[const SizedBox(height: 6), const CommissionBadge(large: true)],
            ],
          ),
        ],
      ),
    );
  }
}

/// "Offline" pill tuned for the navy header (navy-700 fill, hollow dot).
class OfflineHeaderPill extends StatelessWidget {
  const OfflineHeaderPill({super.key});

  @override
  Widget build(BuildContext context) => Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: const BoxDecoration(color: RidoColors.navy700, borderRadius: RidoRadii.pillRadius),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: RidoColors.navy300, width: 2)),
          ),
          const SizedBox(width: RidoSpacing.s),
          Text('Offline', style: context.type.bodySemibold.copyWith(color: Colors.white)),
        ]),
      );
}

/// Big coral round "GO ONLINE" button (disabled shows a lock).
class GoOnlineButton extends StatelessWidget {
  const GoOnlineButton({super.key, required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final fg = enabled ? Colors.white : RidoColors.navy500;
    return Semantics(
      button: true,
      enabled: enabled,
      label: enabled ? 'Go online' : 'Go online, locked',
      excludeSemantics: true,
      child: Material(
        color: enabled ? RidoColors.coral600 : RidoColors.divider,
        shape: const StadiumBorder(),
        elevation: enabled ? 2 : 0,
        shadowColor: RidoColors.shadow,
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onPressed,
          child: SizedBox(
            height: 64,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(enabled ? Symbols.power_settings_new_rounded : Symbols.lock_rounded, color: fg, size: 28, weight: 600),
                const SizedBox(width: RidoSpacing.m),
                Text('GO ONLINE',
                    style: context.type.h2.copyWith(color: fg, letterSpacing: 2, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// White floating card with today's figures ("₹0 today · 0 rides" / "You kept today ₹1,420").
class TodayCard extends StatelessWidget {
  const TodayCard({super.key, required this.earnings, required this.rides, required this.online, required this.onEarnings});

  final int earnings;
  final int rides;
  final bool online;
  final VoidCallback onEarnings;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final ridesLabel = rides == 1 ? '1 ride' : '$rides rides';
    if (!online) {
      return RidoCard(
        shadow: true,
        borderColor: null,
        padding: const EdgeInsets.fromLTRB(RidoSpacing.l, RidoSpacing.s, RidoSpacing.s, RidoSpacing.s),
        child: Row(children: [
          const Icon(Symbols.today_rounded, color: RidoColors.navy900),
          const SizedBox(width: RidoSpacing.m),
          Expanded(
            child: Text('${formatInr(earnings)} today · $ridesLabel',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: RidoTextStyles.tabular(t.h2)),
          ),
          TextButton(onPressed: onEarnings, child: const Text('Earnings')),
        ]),
      );
    }
    return RidoCard(
      shadow: true,
      borderColor: null,
      onTap: onEarnings,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('You kept today', style: t.bodySmall.copyWith(color: RidoColors.navy500)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(formatInr(earnings), style: t.heroSmall),
              const SizedBox(width: RidoSpacing.m),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(text: '$ridesLabel · '),
                      TextSpan(
                          text: '₹0',
                          style: t.bodySmallMedium.copyWith(color: RidoColors.success, fontWeight: FontWeight.w700)),
                      const TextSpan(text: ' commission'),
                    ]),
                    textAlign: TextAlign.end,
                    maxLines: 2,
                    style: RidoTextStyles.tabular(t.bodySmallMedium.copyWith(color: RidoColors.navy700)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// D-25a amber banner: "Payment failed. 2 days left to renew." + navy "Pay ₹2,000 now".
class GraceBanner extends StatelessWidget {
  const GraceBanner({super.key, required this.daysLeft, required this.amount, required this.onPay});

  final int daysLeft;
  final int? amount;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Container(
      padding: const EdgeInsets.fromLTRB(RidoSpacing.l, RidoSpacing.l, RidoSpacing.l, RidoSpacing.l),
      decoration: BoxDecoration(
        color: RidoColors.warningTint,
        borderRadius: RidoRadii.cardRadius,
        border: Border.all(color: RidoColors.warning),
        boxShadow: RidoShadows.soft,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Symbols.warning_rounded, fill: 1, color: RidoColors.warningText, size: 26),
          const SizedBox(width: RidoSpacing.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Payment failed. $daysLeft ${daysLeft == 1 ? 'day' : 'days'} left to renew.',
                    style: t.bodySemibold),
                const SizedBox(height: 2),
                Text('You can still go online.', style: t.body.copyWith(color: RidoColors.navy700)),
                const SizedBox(height: RidoSpacing.m),
                RidoButton(
                  label: 'Pay ${amount == null ? '₹—' : formatInr(amount!)} now',
                  variant: RidoButtonVariant.dark,
                  expand: false,
                  height: 44,
                  onPressed: onPay,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// D-14b coral strip: "Ride in progress · Priya → Brookefields Mall · 9 min" + Return.
class TripInProgressBanner extends StatelessWidget {
  const TripInProgressBanner({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onOpen,
  });

  final String title;
  final String subtitle;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Material(
      color: RidoColors.coral600,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(RidoSpacing.gutter, RidoSpacing.m, RidoSpacing.m, RidoSpacing.m),
          child: Row(
            children: [
              const Icon(Symbols.navigation_rounded, color: Colors.white, fill: 1, size: 26),
              const SizedBox(width: RidoSpacing.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: t.h2.copyWith(color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: RidoTextStyles.tabular(t.body.copyWith(color: Colors.white.withValues(alpha: 0.92)))),
                  ],
                ),
              ),
              const SizedBox(width: RidoSpacing.s),
              Material(
                color: RidoColors.surface,
                shape: const StadiumBorder(),
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: onOpen,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 14, 12),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text('Return', style: t.bodySemibold.copyWith(color: RidoColors.coral600)),
                      const Icon(Symbols.chevron_right_rounded, color: RidoColors.coral600),
                    ]),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small tinted strip under GO ONLINE ("Bike plan active till 24 Oct 2026").
class PlanStrip extends StatelessWidget {
  const PlanStrip({super.key, required this.text, required this.onTap, this.warning = false});

  final String text;
  final VoidCallback onTap;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final fg = warning ? RidoColors.warningText : RidoColors.navy900;
    return Material(
      color: warning ? RidoColors.warningTint : RidoColors.inputBg,
      borderRadius: RidoRadii.cardRadius,
      child: InkWell(
        borderRadius: RidoRadii.cardRadius,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: RidoSpacing.l, vertical: RidoSpacing.m),
            child: Row(children: [
              Icon(warning ? Symbols.schedule_rounded : Symbols.verified_rounded,
                  size: 22, fill: warning ? 0 : 1, color: warning ? RidoColors.warningText : RidoColors.success),
              const SizedBox(width: RidoSpacing.m),
              Expanded(child: Text(text, style: context.type.body.copyWith(color: fg), maxLines: 2)),
              if (!warning) const Icon(Symbols.chevron_right_rounded, color: RidoColors.navy500),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Green dot + "You're online" + subtitle (D-14 / S-11 panel top).
class OnlineStatusRow extends StatelessWidget {
  const OnlineStatusRow({super.key, required this.title, required this.subtitle, this.icon});

  final String title;
  final String subtitle;

  /// Replaces the green dot (e.g. pause icon for "New requests paused").
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: icon != null
              ? Icon(icon, color: RidoColors.navy700, size: 26)
              : Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(color: RidoColors.successTint, shape: BoxShape.circle),
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(color: RidoColors.success, shape: BoxShape.circle),
                  ),
                ),
        ),
        const SizedBox(width: RidoSpacing.m),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: t.h2),
            Text(subtitle, style: t.body.copyWith(color: RidoColors.navy700)),
          ]),
        ),
      ],
    );
  }
}
