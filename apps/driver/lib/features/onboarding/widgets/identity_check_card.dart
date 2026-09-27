import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import 'signup_widgets.dart';

const _diditPrivacy = 'https://didit.me/terms/verification-privacy-notice';

/// D-07 identity step: driving licence + Aadhaar + selfie, checked in the app by Didit (native screens, no browser).
/// Shows the result, the decline reasons and "Verify" / "Try again".
class IdentityCheckCard extends ConsumerStatefulWidget {
  const IdentityCheckCard({super.key, this.showcase = false});

  /// Design gallery: a fixed "not started" card with no actions.
  final bool showcase;

  @override
  ConsumerState<IdentityCheckCard> createState() => _IdentityCheckCardState();
}

class _IdentityCheckCardState extends ConsumerState<IdentityCheckCard> {
  bool _busy = false;

  Future<void> _verify() async {
    setState(() => _busy = true);
    final error = await ref.read(identityProvider.notifier).verify();
    if (!mounted) return;
    setState(() => _busy = false);
    final check = ref.read(identityProvider).value;
    if (error != null) {
      showRidoSnack(context, error);
    } else if (check?.status == IdentityStatus.approved) {
      showRidoSnack(context, 'Identity verified');
    } else if (check?.status == IdentityStatus.inReview) {
      showRidoSnack(context, "Thanks! We're checking your details");
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final check = widget.showcase
        ? const IdentityCheck(isEnabled: true, status: IdentityStatus.notStarted)
        : ref.watch(identityProvider).value;
    if (check == null || !check.isEnabled) return const SizedBox.shrink();
    final status = check.status;
    final (Color tileBg, Color tileFg) = switch (status) {
      IdentityStatus.approved => (RidoColors.successTint, RidoColors.successText),
      IdentityStatus.inReview => (RidoColors.warningTint, RidoColors.warningText),
      IdentityStatus.declined => (RidoColors.errorTint, RidoColors.error),
      _ => (RidoColors.inputBg, RidoColors.navy700),
    };
    final subtitle = switch (status) {
      IdentityStatus.approved => [
          'Verified',
          for (final d in check.documents)
            if (d.last4 != null) '${d.isDrivingLicence ? 'licence' : 'Aadhaar'} •••• ${d.last4}',
        ].join(' · '),
      IdentityStatus.inReview => "We're checking your details",
      IdentityStatus.declined => check.reasons.isEmpty ? "We couldn't verify you. Please try again" : check.reasons.join('. '),
      IdentityStatus.inProgress => 'Not finished yet. Tap Continue to pick up where you left off',
      IdentityStatus.notStarted => 'Scan your licence and Aadhaar, then take a selfie. Takes about 3 minutes',
    };
    final Widget trailing = switch (status) {
      IdentityStatus.approved => const IconPill(
          label: 'Verified', icon: Symbols.check_circle_rounded, bg: RidoColors.successTint, fg: RidoColors.successText),
      IdentityStatus.inReview => const IconPill(
          label: 'In review', icon: Symbols.schedule_rounded, bg: RidoColors.warningTint, fg: RidoColors.warningText),
      _ => _ActionButton(
          label: switch (status) {
            IdentityStatus.declined => 'Try again',
            IdentityStatus.inProgress => 'Continue',
            _ => 'Verify',
          },
          busy: _busy,
          onTap: widget.showcase || _busy ? null : _verify,
        ),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: RidoColors.surface,
            borderRadius: RidoRadii.cardRadius,
            border: Border.all(color: status == IdentityStatus.declined ? RidoColors.error : RidoColors.divider),
          ),
          padding: const EdgeInsets.all(RidoSpacing.l),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: tileBg, borderRadius: RidoRadii.cardRadius),
                child: Icon(Symbols.face_rounded, color: tileFg, size: 22),
              ),
              const SizedBox(width: RidoSpacing.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Licence, Aadhaar + selfie', style: t.bodySemibold),
                    Text(
                      subtitle,
                      style: t.bodySmall.copyWith(color: status == IdentityStatus.declined ? RidoColors.error : RidoColors.navy500),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: RidoSpacing.s),
              trailing,
            ],
          ),
        ),
        if (check.canStart) ...[
          const SizedBox(height: RidoSpacing.s),
          const IdentityConsentNote(),
        ],
      ],
    );
  }
}

/// Who checks the photos, with Didit's privacy notice (shown before the check starts).
class IdentityConsentNote extends StatelessWidget {
  const IdentityConsentNote({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Semantics(
      link: true,
      child: InkWell(
        onTap: () => launchUrl(Uri.parse(_diditPrivacy), mode: LaunchMode.inAppBrowserView),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: RidoSpacing.xs),
          child: Text.rich(
            TextSpan(
              style: t.bodySmall.copyWith(color: RidoColors.navy500),
              children: [
                const TextSpan(
                    text: 'Rido uses Didit to check your ID and selfie inside the app. By continuing you agree to share them '
                        'with Didit for this check. '),
                TextSpan(text: "Didit's privacy notice", style: t.bodySmallMedium.copyWith(color: RidoColors.coral600)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, required this.onTap, this.busy = false});
  final String label;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) => Material(
        color: RidoColors.coral600,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (busy)
                    const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  else
                    const Icon(Symbols.photo_camera_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 6),
                  Text(label, style: context.type.button.copyWith(color: Colors.white)),
                ],
              ),
            ),
          ),
        ),
      );
}
