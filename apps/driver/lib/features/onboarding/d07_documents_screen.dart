import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

import '../../router/routes.dart';
import '../../state/driver_account.dart';
import 'widgets/signup_widgets.dart';

/// D-07 Documents / KYC checklist: "3 of 5 done", a row per document with its status and
/// an Upload button. Continue (all 5 uploaded) → D-09 selfie.
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
    final docs = readOnly && !live
        ? Seed.kycAllVerified
        : showcase
            ? Seed.kycFresh
            : (ref.watch(kycProvider).value ?? Seed.kycFresh);
    final signup = ref.watch(signupProvider);
    final done = docs.where((d) => d.status == KycStatus.verified || d.status == KycStatus.underReview).length;
    final verified = docs.where((d) => d.status == KycStatus.verified).length;
    final allDone = done == docs.length;
    // Live API: after a restart the sign-up draft is empty, so the vehicle comes from the driver profile.
    final profile = live ? ref.watch(driverProfileProvider).value : null;
    final kind = profile?.vehicleKind ?? signup.vehicle;
    final vehicle = kind == VehicleKind.truck ? 'Truck' : kind.label;
    final work = (profile != null ? !profile.vehicleKind.isGoods : signup.workType == WorkType.rides) ? 'Rides' : 'Deliveries';

    return Scaffold(
      backgroundColor: RidoColors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DocsHeader(
            title: 'Documents',
            step: readOnly ? null : 4,
            summary: readOnly ? '$verified of ${docs.length} verified' : '$done of ${docs.length} done',
            trailing: readOnly ? null : '$vehicle · $work',
            segments: [((readOnly ? verified : done) / docs.length, readOnly ? RidoColors.success : RidoColors.coral500)],
            onBack: readOnly ? null : backOr(context, Routes.personalDetails),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(RidoSpacing.l),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: RidoColors.surface,
                      borderRadius: RidoRadii.cardRadius,
                      border: Border.all(color: RidoColors.divider),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        for (var i = 0; i < docs.length; i++) ...[
                          if (i > 0) const Divider(height: 1),
                          _DocRow(
                            doc: docs[i],
                            // Live: a rejected document can be re-uploaded from Account too.
                            readOnly: readOnly && !(live && docs[i].status == KycStatus.rejected),
                            live: live,
                            onUpload: () => context.push(Routes.uploadDocument(docs[i].type.name)),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: RidoSpacing.l),
                  if (readOnly)
                    Text(
                        verified == docs.length
                            ? 'All your documents are verified. Contact support if something changes, like a new RC.'
                            : 'An admin checks each document, usually within 24 hours. Contact support if you need help.',
                        style: t.bodySmall.copyWith(color: RidoColors.navy500))
                  else
                    Container(
                      padding: const EdgeInsets.all(RidoSpacing.l),
                      decoration: const BoxDecoration(color: RidoColors.navy900, borderRadius: RidoRadii.cardRadius),
                      child: Row(
                        children: [
                          const Icon(Symbols.lightbulb_rounded, color: Colors.white),
                          const SizedBox(width: RidoSpacing.m),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Clear photos get approved faster',
                                    style: t.bodySemibold.copyWith(color: Colors.white)),
                                Text('Good light, all 4 corners visible, no glare.',
                                    style: t.bodySmall.copyWith(color: RidoColors.navy300)),
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
                RidoButton(label: 'Continue', onPressed: allDone ? () => context.push(Routes.selfie) : null),
                if (!allDone) ...[
                  const SizedBox(height: RidoSpacing.s),
                  Text('Upload all ${docs.length} to continue',
                      textAlign: TextAlign.center, style: t.bodySmall.copyWith(color: RidoColors.navy500)),
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
      KycStatus.verified => (RidoColors.successTint, RidoColors.successText),
      KycStatus.underReview => (RidoColors.warningTint, RidoColors.warningText),
      KycStatus.rejected => (RidoColors.errorTint, RidoColors.error),
      KycStatus.notUploaded => (RidoColors.inputBg, RidoColors.navy700),
    };
    final subtitle = switch (doc.status) {
      KycStatus.verified => live ? 'Verified by Rido' : verifiedLine,
      KycStatus.underReview when live => 'Uploaded · an admin is checking it',
      KycStatus.underReview => doc.type == KycDocType.vehicleRc ? 'Uploaded 10:08 AM' : 'Uploaded just now',
      KycStatus.rejected => doc.rejectReason ?? Seed.kycRejectReason,
      KycStatus.notUploaded => hint,
    };
    final Widget trailing = switch (doc.status) {
      KycStatus.verified => const IconPill(
          label: 'Verified',
          icon: Symbols.check_circle_rounded,
          bg: RidoColors.successTint,
          fg: RidoColors.successText),
      KycStatus.underReview => const IconPill(
          label: 'Under review',
          icon: Symbols.schedule_rounded,
          bg: RidoColors.warningTint,
          fg: RidoColors.warningText),
      KycStatus.rejected => _UploadButton(label: 'Re-upload', onTap: onUpload),
      KycStatus.notUploaded => _UploadButton(label: 'Upload', onTap: onUpload),
    };
    return Padding(
      padding: const EdgeInsets.all(RidoSpacing.l),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: tileBg, borderRadius: RidoRadii.cardRadius),
            child: Icon(icon, color: tileFg, size: 22),
          ),
          const SizedBox(width: RidoSpacing.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(doc.type.label, style: t.bodySemibold),
                Text(
                  subtitle,
                  style: t.bodySmall.copyWith(
                      color: doc.status == KycStatus.rejected ? RidoColors.error : RidoColors.navy500),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: RidoSpacing.s),
          if (readOnly && !live)
            const IconPill(
                label: 'Verified', icon: Symbols.check_circle_rounded, bg: RidoColors.successTint, fg: RidoColors.successText)
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
