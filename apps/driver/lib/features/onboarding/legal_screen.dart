import 'package:flutter/material.dart';
import 'package:tamiltaxi_ui/tamiltaxi_ui.dart';

import 'widgets/signup_widgets.dart';

/// Driver Terms / Privacy Policy: a simple scrollable text screen ([doc] is `terms` or `privacy`).
class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, this.doc = 'terms', this.showcase = false});

  final String doc;

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  static const _terms = <(String, String)>[
    (
      'Free to use',
      'Tamil Taxi charges no commission and no subscription for any vehicle type. It runs on voluntary contributions '
          'from drivers and riders (Account › Contribute); contributing is never required to get requests.'
    ),
    (
      'You keep 100% of fares',
      'Riders pay you directly by cash or UPI. Tamil Taxi never takes a share of a fare, tip or waiting charge.'
    ),
    (
      'Documents and safety',
      'You must keep a valid driving licence, vehicle RC, insurance and police verification. We may ask for a quick '
          'selfie before you go online to confirm it is you.'
    ),
    (
      'Conduct',
      'Treat riders and receivers with respect, follow traffic rules and never carry prohibited goods. Repeated '
          'complaints may put your account on hold while we review them.'
    ),
  ];

  static const _privacy = <(String, String)>[
    (
      'What we collect',
      'Your name, phone number, documents, selfie, vehicle details, UPI ID and your location while you are online.'
    ),
    (
      'How we use it',
      'To verify you, match you with nearby requests, show riders your approach and keep everyone safe. We do not '
          'sell your data.'
    ),
    (
      'Location',
      'We use your location only while you are online or on a job. Going offline stops location sharing.'
    ),
    (
      'Your choices',
      'You can update your details from Account, download your data or ask us to delete your account from Help & support.'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final privacy = doc == 'privacy';
    final sections = privacy ? _privacy : _terms;
    return Scaffold(
      backgroundColor: TtColors.surface,
      appBar: SignupAppBar(title: privacy ? 'Privacy Policy' : 'Driver Terms'),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(TtSpacing.l, TtSpacing.xl, TtSpacing.l, TtSpacing.xxl),
          children: [
            Text(privacy ? 'Tamil Taxi Driver Privacy Policy' : 'Tamil Taxi Driver Terms of Service', style: t.h1),
            const SizedBox(height: TtSpacing.xs),
            Text('Last updated 1 Sep 2026', style: t.caption.copyWith(color: TtColors.navy500)),
            for (final (title, body) in sections) ...[
              const SizedBox(height: TtSpacing.xl),
              Text(title, style: t.h2),
              const SizedBox(height: TtSpacing.s),
              Text(body, style: t.body.copyWith(color: TtColors.navy700)),
            ],
            const SizedBox(height: TtSpacing.xl),
            Text('Questions? Write to support@tamiltaxi.co.in or use Help & support in the app.',
                style: t.bodySmall.copyWith(color: TtColors.navy500)),
          ],
        ),
      ),
    );
  }
}
