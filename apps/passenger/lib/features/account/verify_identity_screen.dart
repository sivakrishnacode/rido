import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';
import 'package:url_launcher/url_launcher.dart';

const _diditPrivacy = 'https://didit.me/terms/verification-privacy-notice';

/// Account › Verify identity (optional): scan any Indian ID and take a selfie inside the app (Didit's native
/// screens, no browser). Approved riders get a Verified badge that drivers see on the request.
class VerifyIdentityScreen extends ConsumerStatefulWidget {
  const VerifyIdentityScreen({super.key});

  @override
  ConsumerState<VerifyIdentityScreen> createState() => _VerifyIdentityScreenState();
}

class _VerifyIdentityScreenState extends ConsumerState<VerifyIdentityScreen> {
  bool _busy = false;

  Future<void> _verify() async {
    setState(() => _busy = true);
    final error = await ref.read(identityProvider.notifier).verify();
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) showRidoSnack(context, error);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final check = ref.watch(identityProvider).value;
    final status = check?.status ?? IdentityStatus.notStarted;
    final (IconData icon, Color bg, Color fg, String title, String body) = switch (status) {
      IdentityStatus.approved => (
          Symbols.verified_rounded,
          RidoColors.successTint,
          RidoColors.successText,
          "You're verified",
          'Drivers see a Verified badge when you book.',
        ),
      IdentityStatus.inReview => (
          Symbols.schedule_rounded,
          RidoColors.warningTint,
          RidoColors.warningText,
          "We're checking your details",
          "This usually takes a few hours. We'll let you know.",
        ),
      IdentityStatus.declined => (
          Symbols.error_rounded,
          RidoColors.errorTint,
          RidoColors.error,
          "We couldn't verify you",
          check!.reasons.isEmpty ? 'Please try again with a clear photo of your ID.' : 'Fix this and try again:',
        ),
      _ => (
          Symbols.shield_person_rounded,
          RidoColors.inputBg,
          RidoColors.navy700,
          'Get a Verified badge',
          'Optional. Drivers see the badge when you book, so they know who they are picking up.',
        ),
    };
    final doc = check?.documents.lastOrNull;
    return Scaffold(
      appBar: const RidoAppBar(
        title: 'Verify identity',
        bottom: PreferredSize(preferredSize: Size.fromHeight(1), child: Divider(height: 1)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(RidoSpacing.l),
        children: [
          Center(
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
              child: Icon(icon, size: 44, color: fg, fill: 1),
            ),
          ),
          const SizedBox(height: RidoSpacing.l),
          Text(title, style: t.h1, textAlign: TextAlign.center),
          const SizedBox(height: RidoSpacing.xs),
          Text(body, style: t.body.copyWith(color: RidoColors.navy700), textAlign: TextAlign.center),
          if (status == IdentityStatus.declined && check!.reasons.isNotEmpty) ...[
            const SizedBox(height: RidoSpacing.m),
            Container(
              padding: const EdgeInsets.all(RidoSpacing.l),
              decoration: const BoxDecoration(color: RidoColors.errorTint, borderRadius: RidoRadii.cardRadius),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final r in check.reasons)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: RidoSpacing.xs),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Icon(Symbols.error_rounded, color: RidoColors.error, size: 18, fill: 1),
                          ),
                          const SizedBox(width: RidoSpacing.s),
                          Expanded(child: Text(identityReasonSentence(r), style: t.bodySmall.copyWith(color: RidoColors.navy900))),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (status == IdentityStatus.approved && doc?.last4 != null) ...[
            const SizedBox(height: RidoSpacing.s),
            Text('${doc!.type} •••• ${doc.last4}',
                style: RidoTextStyles.tabular(t.bodySmall.copyWith(color: RidoColors.navy500)), textAlign: TextAlign.center),
          ],
          if (check != null && check.canStart) ...[
            const SizedBox(height: RidoSpacing.xl),
            const _Step(icon: Symbols.id_card_rounded, text: 'Scan any Indian ID: Aadhaar, PAN, Voter ID, driving licence or passport'),
            const _Step(icon: Symbols.face_rounded, text: 'Take a quick selfie so we know it’s you'),
            const _Step(icon: Symbols.timer_rounded, text: 'About 2 minutes, right here in the app'),
            const SizedBox(height: RidoSpacing.l),
            RidoButton(
              label: switch (status) {
                IdentityStatus.declined => 'Try again',
                IdentityStatus.inProgress => 'Continue',
                _ => 'Verify now',
              },
              icon: Symbols.photo_camera_rounded,
              loading: _busy,
              onPressed: _busy ? null : _verify,
            ),
            const SizedBox(height: RidoSpacing.m),
            Semantics(
              link: true,
              child: InkWell(
                onTap: () => launchUrl(Uri.parse(_diditPrivacy), mode: LaunchMode.inAppBrowserView),
                child: Text.rich(
                  TextSpan(
                    style: t.bodySmall.copyWith(color: RidoColors.navy500),
                    children: [
                      const TextSpan(
                          text: 'Rido uses Didit to check your ID and selfie. By continuing you agree to share them with '
                              'Didit for this check. We keep only your name and the last 4 digits of the ID. '),
                      TextSpan(text: "Didit's privacy notice", style: t.bodySmallMedium.copyWith(color: RidoColors.coral600)),
                    ],
                  ),
                ),
              ),
            ),
          ],
          if (check != null && !check.isEnabled) ...[
            const SizedBox(height: RidoSpacing.xl),
            Text('Identity checks open soon.', style: t.bodySmall.copyWith(color: RidoColors.navy500), textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: RidoSpacing.s),
        child: Row(
          children: [
            Icon(icon, color: RidoColors.coral600, size: 24),
            const SizedBox(width: RidoSpacing.m),
            Expanded(child: Text(text, style: context.type.body)),
          ],
        ),
      );
}
