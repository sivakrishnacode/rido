import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:rido_ui/rido_ui.dart';

import '../../router/routes.dart';
import 'p23_account_screen.dart';

/// Account › About Rido: wordmark, version, the 0% commission mission, and links.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key, this.showcase = false});

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Scaffold(
      appBar: const RidoAppBar(
        title: 'About Rido',
        bottom: PreferredSize(preferredSize: Size.fromHeight(1), child: Divider(height: 1)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 32, 16, 24),
        children: [
          const Center(child: RidoWordmark(size: 56)),
          const SizedBox(height: 8),
          Text('Version ${P23AccountScreen.version}',
              style: t.bodySmall.copyWith(color: RidoColors.navy500), textAlign: TextAlign.center),
          const SizedBox(height: 12),
          const Center(child: CommissionBadge(large: true)),
          const SizedBox(height: 24),
          Text(
            'Rido is a free ride and parcel app built in Coimbatore. Drivers pay no commission and no '
            'subscription, so they keep 100% of each fare and you pay a fair price, directly to them in cash '
            'or UPI. Rido runs on contributions from the people who use it.',
            style: t.body.copyWith(color: RidoColors.navy700),
          ),
          const SizedBox(height: 24),
          RidoListGroup(children: [
            RidoListTile(
              icon: Symbols.gavel_rounded,
              title: 'Terms of service',
              onTap: () => context.push(Routes.legal('terms')),
            ),
            RidoListTile(
              icon: Symbols.policy_rounded,
              title: 'Privacy policy',
              onTap: () => context.push(Routes.legal('privacy')),
            ),
            RidoListTile(
              icon: Symbols.star_rounded,
              title: 'Rate us',
              onTap: () => showRidoSnack(context, 'Thanks! Opening the Play Store'),
            ),
          ]),
          const SizedBox(height: 24),
          Text('Made in Coimbatore', style: t.caption, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
