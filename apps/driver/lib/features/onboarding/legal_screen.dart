import 'package:flutter/material.dart';
import 'package:rido_ui/rido_ui.dart';

import 'widgets/signup_widgets.dart';

/// Driver Terms / Privacy Policy: a simple scrollable text screen ([doc] is `terms` or `privacy`).
class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, this.doc = 'terms', this.showcase = false});

  final String doc;

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  static const _terms = <(String, String)>[
    (
      'Your subscription',
      'Rido charges a flat monthly plan for your vehicle type instead of a commission. Bike, auto and cab plans are '
          '₹2,000 a month, 3-wheeler goods ₹3,000 and mini truck ₹4,000. The first month is free for every plan.'
    ),
    (
      'You keep 100% of fares',
      'Riders pay you directly by cash or UPI. Rido never takes a share of a fare, tip or waiting charge.'
    ),
    (
      'UPI Autopay',
      'Your plan renews through UPI Autopay on the same date each month. If a payment fails, you get a 2-day grace '
          'period to pay before going online is paused. You can pause or cancel from the Plan tab at any time.'
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
      backgroundColor: RidoColors.surface,
      appBar: SignupAppBar(title: privacy ? 'Privacy Policy' : 'Driver Terms'),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(RidoSpacing.l, RidoSpacing.xl, RidoSpacing.l, RidoSpacing.xxl),
          children: [
            Text(privacy ? 'Rido Driver Privacy Policy' : 'Rido Driver Terms of Service', style: t.h1),
            const SizedBox(height: RidoSpacing.xs),
            Text('Last updated 1 Sep 2026', style: t.caption.copyWith(color: RidoColors.navy500)),
            for (final (title, body) in sections) ...[
              const SizedBox(height: RidoSpacing.xl),
              Text(title, style: t.h2),
              const SizedBox(height: RidoSpacing.s),
              Text(body, style: t.body.copyWith(color: RidoColors.navy700)),
            ],
            const SizedBox(height: RidoSpacing.xl),
            Text('Questions? Write to support@rido.in or use Help & support in the app.',
                style: t.bodySmall.copyWith(color: RidoColors.navy500)),
          ],
        ),
      ),
    );
  }
}
