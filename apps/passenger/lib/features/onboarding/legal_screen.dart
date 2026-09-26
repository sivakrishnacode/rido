import 'package:flutter/material.dart';
import 'package:rido_ui/rido_ui.dart';

class _Section {
  const _Section(this.heading, this.body);
  final String heading;
  final String body;
}

const _terms = [
  _Section(
    '1. About Rido',
    'Rido is a technology platform that connects passengers and senders in Coimbatore with independent '
        'drivers of bikes, autos, cabs and goods vehicles. Rido does not own vehicles or employ drivers.',
  ),
  _Section(
    '2. Drivers are independent',
    'Every driver on Rido is an independent service provider. Rido is free for drivers: no subscription, and '
        'they keep 100% of every fare. Rido takes 0% commission on rides and deliveries.',
  ),
  _Section(
    '3. Fares and payment',
    'The fare shown before you book is locked at booking. Peak-time pricing is capped at 1.5x and goes to '
        'your driver. You pay the driver directly by cash or UPI; Rido does not collect fares.',
  ),
  _Section(
    '4. Cancellations',
    'You can cancel a request at any time before the ride starts. Repeated late cancellations may limit '
        'your access to the app so that drivers are not kept waiting.',
  ),
  _Section(
    '5. Safety and conduct',
    'Please treat drivers with respect, wear a helmet on bike rides and never carry prohibited items in a '
        'parcel. In an emergency, use SOS in the app or call 112.',
  ),
  _Section(
    '6. Parcels',
    'You are responsible for what you send. Rido connects you with drivers and is not liable for lost or '
        'damaged goods; loading and unloading is done by the sender and receiver.',
  ),
  _Section(
    '7. Service area',
    'Rido currently operates across Coimbatore. Bookings with a pickup outside the service area cannot be made.',
  ),
  _Section(
    '8. Contact',
    'Questions about these terms? Write to support from Help & support in the app. These terms are governed '
        'by the laws of India, with courts in Coimbatore, Tamil Nadu.',
  ),
];

const _privacy = [
  _Section(
    'What we collect',
    'Your name, mobile number, optional email, gender (only if you choose to share it) and your trip '
        'history. While you book or ride, we use your device location.',
  ),
  _Section(
    'How we use it',
    'To find nearby drivers, show your pickup to your driver, calculate fares, share your live trip with '
        'your emergency contacts when you ask us to, and help you if something goes wrong.',
  ),
  _Section(
    'What drivers see',
    'Your first name, pickup and drop. Calls go through a masked number, so drivers never see your real '
        'phone number. Your gender is only used for the "Prefer women driver" option and is never shown.',
  ),
  _Section(
    'Sharing',
    'We do not sell your data. We share it only with your driver for the current trip, with emergency '
        'services when you use SOS, and when the law requires it.',
  ),
  _Section(
    'Location',
    'Rido uses your location only while the app is open or a trip is in progress. You can turn it off in '
        'your phone settings and enter your pickup manually.',
  ),
  _Section(
    'Keeping and deleting data',
    'Trip records are kept for 3 years for safety and tax purposes. You can ask us to delete your account '
        'and personal data at any time from Help & support.',
  ),
];

/// Terms of service and Privacy policy: a simple scrollable text screen.
class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, this.doc = 'terms', this.showcase = false});

  /// 'terms' or 'privacy'.
  final String doc;

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final isPrivacy = doc == 'privacy';
    final sections = isPrivacy ? _privacy : _terms;
    return Scaffold(
      backgroundColor: RidoColors.surface,
      appBar: RidoAppBar(title: isPrivacy ? 'Privacy policy' : 'Terms of service'),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(RidoSpacing.l, RidoSpacing.s, RidoSpacing.l, RidoSpacing.xxl),
          children: [
            Text('Last updated 1 Sep 2026', style: t.caption),
            const SizedBox(height: RidoSpacing.m),
            Text(
              isPrivacy
                  ? 'Your privacy matters to us. This policy explains what Rido collects and why.'
                  : 'These terms apply when you use the Rido app to book rides or send parcels in Coimbatore.',
              style: t.body.copyWith(color: RidoColors.navy700),
            ),
            for (final s in sections) ...[
              const SizedBox(height: RidoSpacing.xl),
              Text(s.heading, style: t.h2),
              const SizedBox(height: RidoSpacing.s),
              Text(s.body, style: t.body.copyWith(color: RidoColors.navy700)),
            ],
          ],
        ),
      ),
    );
  }
}
