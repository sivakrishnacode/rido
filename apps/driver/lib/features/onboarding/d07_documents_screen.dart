import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';
import 'package:tamiltaxi_ui/tamiltaxi_ui.dart';

import '../../router/routes.dart';
import '../../state/driver_account.dart';
import 'widgets/identity_check_card.dart';
import 'widgets/profile_photo_card.dart';
import 'widgets/signup_widgets.dart';

/// D-07 Documents / KYC checklist: the in-app identity check (driving licence + Aadhaar + selfie, by Didit) and a row
/// per document to upload (RC, insurance) with its status and an Upload button. Continue (identity done and
/// both uploaded) → D-10 under review.
/// [readOnly] (Account → Documents) shows every document as verified, with no actions (live API: the
/// real statuses, with Re-upload for a rejected document).
class D07DocumentsScreen extends ConsumerWidget {
  const D07DocumentsScreen({super.key, this.readOnly = false, this.showcase = false});

  final bool readOnly;

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.type;
    final live = !showcase && ref.watch(isLiveApiProvider);
    final allDocs = readOnly && !live
        ? Seed.kycAllVerified
        : showcase
            ? Seed.kycFresh
            : (ref.watch(kycProvider).value ?? Seed.kycFresh);
    final docs = [for (final d in allDocs) if (driverUploadDocs.contains(d.type)) d];
    final identity = showcase ? null : ref.watch(identityProvider).value;
    // Didit off (dev) counts as done; so does a check waiting for review.
    final isIdentityDone = identity == null ? showcase : (!identity.isEnabled || identity.isSubmitted);
    final hasIdentity = identity?.isEnabled ?? showcase;
    final signup = ref.watch(signupProvider);
    final done = docs.where((d) => d.status == KycStatus.verified || d.status == KycStatus.underReview).length;
    final verified = docs.where((d) => d.status == KycStatus.verified).length;
    final steps = docs.length + (hasIdentity ? 1 : 0);
    final stepsDone = done + (hasIdentity && isIdentityDone ? 1 : 0);
    final stepsVerified = verified + (identity?.isApproved == true ? 1 : 0);
    // Live API: after a restart the sign-up draft is empty, so the vehicle comes from the driver profile.
    final profile = live ? ref.watch(driverProfileProvider).value : null;
    // Once the identity check is approved, the profile photo is needed too (riders see it).
    final isPhotoDone = !live || identity == null || !identity.isApproved || profile?.photoPath != null || (profile?.hasPendingPhoto ?? false);
    final allDone = done == docs.length && isIdentityDone && isPhotoDone;
    final kind = profile?.vehicleKind ?? signup.vehicle;
    final vehicle = kind == VehicleKind.truck ? 'Truck' : kind.label;
    final work = (profile != null ? !profile.vehicleKind.isGoods : signup.workType == WorkType.rides) ? 'Rides' : 'Deliveries';

    return Scaffold(
      backgroundColor: TtColors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DocsHeader(
            title: 'Documents',
            step: readOnly ? null : 4,
            summary: readOnly ? '$stepsVerified of $steps verified' : '$stepsDone of $steps done',
            trailing: readOnly ? null : '$vehicle · $work',
            segments: [((readOnly ? stepsVerified : stepsDone) / steps, readOnly ? TtColors.success : TtColors.coral500)],
            onBack: readOnly ? null : backOr(context, Routes.personalDetails),
            onHelp: showcase ? null : () => context.push(Routes.help),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(TtSpacing.l),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (hasIdentity) ...[
                    IdentityCheckCard(showcase: showcase),
                    const SizedBox(height: TtSpacing.l),
                    if (!showcase) ...[
                      const ProfilePhotoCard(),
                      const SizedBox(height: TtSpacing.l),
                    ],
                  ],
                  // One card per document, outlined by its status (green once done), like Namma Yatri's checklist.
                  for (final doc in docs) ...[
                    _DocRow(
                      doc: doc,
                      // Live: a rejected document can be re-uploaded from Account too.
                      readOnly: readOnly && !(live && doc.status == KycStatus.rejected),
                      live: live,
                      onUpload: () => context.push(Routes.uploadDocument(doc.type.name)),
                    ),
                    const SizedBox(height: TtSpacing.m),
                  ],
                  const SizedBox(height: TtSpacing.l),
                  if (readOnly)
                    Text(
                        // Counts the identity check too: a declined check is never "all verified".
                        identity?.status == IdentityStatus.declined
                            ? 'Your identity check needs another try. Fix the points above, then tap Try again.'
                            : stepsVerified == steps
                                ? 'All your documents are verified. Contact support if something changes, like a new RC.'
                                : 'An admin checks each document, usually within 24 hours. Contact support if you need help.',
                        style: t.bodySmall.copyWith(color: TtColors.navy500))
                  else
                    Container(
                      padding: const EdgeInsets.all(TtSpacing.l),
                      decoration: const BoxDecoration(color: TtColors.navy900, borderRadius: TtRadii.cardRadius),
                      child: Row(
                        children: [
                          const Icon(Symbols.lightbulb_rounded, color: Colors.white),
                          const SizedBox(width: TtSpacing.m),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Clear photos get approved faster',
                                    style: t.bodySemibold.copyWith(color: Colors.white)),
                                Text('Good light, all 4 corners visible, no glare.',
                                    style: t.bodySmall.copyWith(color: TtColors.navy300)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (!readOnly)
            BottomActions(
              children: [
                TtButton(label: 'Continue', onPressed: allDone ? () => context.go(Routes.underReview) : null),
                if (!allDone) ...[
                  const SizedBox(height: TtSpacing.s),
                  Text(!isIdentityDone
                      ? 'Verify your licence and Aadhaar, and upload both documents to continue'
                      : !isPhotoDone
                          ? 'Take your profile photo to continue'
                          : 'Upload both documents to continue',
                      textAlign: TextAlign.center, style: t.bodySmall.copyWith(color: TtColors.navy500)),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

/// Icon, sample detail line and verified subtitle for each document.
(IconData, String, String) _docInfo(KycDocType type) => switch (type) {
      KycDocType.drivingLicence => (Symbols.id_card_rounded, 'Front and back of your licence', 'TN37 •••• 2345'),
      KycDocType.aadhaar => (Symbols.fingerprint_rounded, 'Front and back', '•••• •••• 7781'),
      KycDocType.vehicleRc => (Symbols.description_rounded, 'Registration certificate', 'TN 37 AB 4521'),
      KycDocType.insurance => (Symbols.shield_rounded, 'Policy page with dates', 'Valid till 12 Mar 2027'),
      KycDocType.policeVerification => (Symbols.local_police_rounded, 'From TN Police eServices', 'Verified by TN Police'),
    };

class _DocRow extends StatelessWidget {
  const _DocRow({required this.doc, required this.readOnly, required this.onUpload, this.live = false});

  final KycDocument doc;
  final bool readOnly;
  final VoidCallback onUpload;

  /// Real statuses: no sample document numbers or upload times.
  final bool live;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final (icon, hint, verifiedLine) = _docInfo(doc.type);
    final (Color tileBg, Color tileFg) = switch (doc.status) {
      KycStatus.verified => (TtColors.successTint, TtColors.successText),
      KycStatus.underReview => (TtColors.warningTint, TtColors.warningText),
      KycStatus.rejected => (TtColors.errorTint, TtColors.error),
      KycStatus.notUploaded => (TtColors.inputBg, TtColors.navy700),
    };
    final subtitle = switch (doc.status) {
      KycStatus.verified => live ? 'Verified by Tamil Taxi' : verifiedLine,
      KycStatus.underReview when live => 'Uploaded · an admin is checking it',
      KycStatus.underReview => doc.type == KycDocType.vehicleRc ? 'Uploaded 10:08 AM' : 'Uploaded just now',
      KycStatus.rejected => doc.rejectReason ?? Seed.kycRejectReason,
      KycStatus.notUploaded => hint,
    };
    final Widget trailing = switch (doc.status) {
      KycStatus.verified => const IconPill(
          label: 'Verified',
          icon: Symbols.check_circle_rounded,
          bg: TtColors.successTint,
          fg: TtColors.successText),
      KycStatus.underReview => const IconPill(
          label: 'Under review',
          icon: Symbols.schedule_rounded,
          bg: TtColors.warningTint,
          fg: TtColors.warningText),
      KycStatus.rejected => _UploadButton(label: 'Re-upload', onTap: onUpload),
      KycStatus.notUploaded => _UploadButton(label: 'Upload', onTap: onUpload),
    };
    final shownVerified = readOnly && !live;
    final outline = shownVerified
        ? TtColors.success
        : switch (doc.status) {
            KycStatus.verified => TtColors.success,
            KycStatus.underReview => TtColors.warning,
            KycStatus.rejected => TtColors.error,
            KycStatus.notUploaded => TtColors.divider,
          };
    return Container(
      padding: const EdgeInsets.all(TtSpacing.l),
      decoration: BoxDecoration(
        color: TtColors.surface,
        borderRadius: TtRadii.cardRadius,
        border: Border.all(
          color: outline.withValues(alpha: outline == TtColors.divider ? 1 : 0.55),
          width: outline == TtColors.divider ? 1 : 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: tileBg, borderRadius: TtRadii.cardRadius),
            child: Icon(icon, color: tileFg, size: 22),
          ),
          const SizedBox(width: TtSpacing.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(doc.type.label, style: t.bodySemibold),
                Text(
                  subtitle,
                  style: t.bodySmall.copyWith(
                      color: doc.status == KycStatus.rejected ? TtColors.error : TtColors.navy500),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: TtSpacing.s),
          if (shownVerified)
            const IconPill(
                label: 'Verified', icon: Symbols.check_circle_rounded, bg: TtColors.successTint, fg: TtColors.successText)
          else
            trailing,
        ],
      ),
    );
  }
}

class _UploadButton extends StatelessWidget {
  const _UploadButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: TtColors.coral600,
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
                  const Icon(Symbols.upload_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 6),
                  Text(label, style: context.type.button.copyWith(color: Colors.white)),
                ],
              ),
            ),
          ),
        ),
      );
}
