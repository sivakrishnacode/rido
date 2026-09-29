import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';
import 'package:tamiltaxi_ui/tamiltaxi_ui.dart';

import '../../router/routes.dart';
import '../../state/driver_account.dart';
import '../onboarding/widgets/signup_widgets.dart';

/// S-09 KYC rejected: Vehicle RC rejected ("Photo is blurry…") with "Re-upload" → D-08.
/// Live API: whichever document the admin rejected, with the admin's reason and the others' real status.
class S09KycRejectedScreen extends ConsumerWidget {
  const S09KycRejectedScreen({super.key, this.showcase = false});

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  void _reupload(BuildContext context, WidgetRef ref, KycDocType type) {
    ref.read(demoSettingsProvider.notifier).update((s) => s.copyWith(rejectKyc: false));
    final router = GoRouter.of(context);
    // Push the camera as soon as the documents route is in place.
    final delegate = router.routerDelegate;
    void onChange() {
      if (delegate.currentConfiguration.uri.path != Routes.documents) return;
      delegate.removeListener(onChange);
      router.push(Routes.uploadDocument(type.name));
    }

    delegate.addListener(onChange);
    router.go(Routes.documents);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.type;
    final docs = showcase ? null : ref.watch(kycProvider).value;
    final rejected = docs?.where((d) => d.status == KycStatus.rejected).firstOrNull ??
        docs?.where((d) => d.type == KycDocType.vehicleRc).firstOrNull;
    final rejectedType = rejected?.type ?? KycDocType.vehicleRc;
    final reason = rejected?.rejectReason ?? Seed.kycRejectReason;
    final others = [
      for (final type in driverUploadDocs)
        if (type != rejectedType)
          docs?.where((d) => d.type == type).firstOrNull ?? KycDocument(type: type, status: KycStatus.verified),
    ];
    final verified = others.where((d) => d.status == KycStatus.verified).length;
    final total = driverUploadDocs.length;

    return Scaffold(
      backgroundColor: TtColors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DocsHeader(
            title: 'Documents',
            summary: '$verified of $total verified',
            trailing: '1 needs action',
            trailingColor: TtColors.coral100,
            segments: [(verified / total, TtColors.success), (1 / total, TtColors.sos)],
            onBack: backOr(context, Routes.documents),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(TtSpacing.l),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: TtColors.surface,
                      borderRadius: TtRadii.cardRadius,
                      border: Border.all(color: TtColors.error),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(TtSpacing.l),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration:
                                    const BoxDecoration(color: TtColors.errorTint, borderRadius: TtRadii.cardRadius),
                                child: const Icon(Symbols.description_rounded, color: TtColors.error, size: 22),
                              ),
                              const SizedBox(width: TtSpacing.m),
                              Expanded(child: Text(rejectedType.label, style: t.bodySemibold)),
                              const IconPill(
                                label: 'Rejected',
                                icon: Symbols.cancel_rounded,
                                bg: TtColors.errorTint,
                                fg: TtColors.error,
                              ),
                            ],
                          ),
                        ),
                        Container(
                          color: TtColors.errorTint,
                          padding: const EdgeInsets.all(TtSpacing.l),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Semantics(
                                    image: true,
                                    label: 'Your rejected ${rejectedType.label} photo',
                                    child: Container(
                                      width: 72,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: TtColors.navy300.withValues(alpha: 0.7),
                                        borderRadius: const BorderRadius.all(Radius.circular(8)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: TtSpacing.m),
                                  Expanded(child: Text(reason, style: t.body)),
                                ],
                              ),
                              const SizedBox(height: TtSpacing.l),
                              TtButton(
                                label: 'Re-upload',
                                icon: Symbols.photo_camera_rounded,
                                onPressed: () => _reupload(context, ref, rejectedType),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: TtSpacing.l),
                  Container(
                    decoration: BoxDecoration(
                      color: TtColors.surface,
                      borderRadius: TtRadii.cardRadius,
                      border: Border.all(color: TtColors.divider),
                    ),
                    child: Column(
                      children: [
                        for (var i = 0; i < others.length; i++) ...[
                          if (i > 0) const Divider(height: 1),
                          SizedBox(
                            height: 56,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: TtSpacing.l),
                              child: Row(
                                children: [
                                  others[i].status == KycStatus.verified
                                      ? const Icon(Symbols.check_circle_rounded, color: TtColors.success, fill: 1)
                                      : const Icon(Symbols.schedule_rounded, color: TtColors.warning, fill: 1),
                                  const SizedBox(width: TtSpacing.m),
                                  Expanded(
                                    child: Text(others[i].type.label,
                                        style: t.body, maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ),
                                  Text(
                                    switch (others[i].status) {
                                      KycStatus.verified => 'Verified',
                                      KycStatus.underReview => 'Under review',
                                      KycStatus.rejected => 'Rejected',
                                      KycStatus.notUploaded => 'Not uploaded',
                                    },
                                    style: t.bodySmallMedium.copyWith(
                                        color: others[i].status == KycStatus.verified
                                            ? TtColors.successText
                                            : TtColors.warningText),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: TtSpacing.l),
                  Row(
                    children: [
                      const Icon(Symbols.lightbulb_rounded, size: 18, color: TtColors.navy500),
                      const SizedBox(width: TtSpacing.s),
                      Expanded(
                        child: Text('Good light, all 4 corners visible, no glare.',
                            style: t.bodySmall.copyWith(color: TtColors.navy500)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
