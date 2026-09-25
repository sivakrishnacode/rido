import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

import '../../router/routes.dart';
import '../../state/driver_account.dart';
import '../onboarding/widgets/signup_widgets.dart';

/// S-09 KYC rejected: Vehicle RC rejected ("Photo is blurry…") with "Re-upload" → D-08.
class S09KycRejectedScreen extends ConsumerWidget {
  const S09KycRejectedScreen({super.key, this.showcase = false});

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  void _reupload(BuildContext context, WidgetRef ref) {
    ref.read(demoSettingsProvider.notifier).update((s) => s.copyWith(rejectKyc: false));
    final router = GoRouter.of(context);
    // Push the camera as soon as the documents route is in place.
    final delegate = router.routerDelegate;
    void onChange() {
      if (delegate.currentConfiguration.uri.path != Routes.documents) return;
      delegate.removeListener(onChange);
      router.push(Routes.uploadDocument(KycDocType.vehicleRc.name));
    }

    delegate.addListener(onChange);
    router.go(Routes.documents);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.type;
    final docs = showcase ? null : ref.watch(kycProvider).value;
    final rc = docs?.where((d) => d.type == KycDocType.vehicleRc).firstOrNull;
    final reason = rc?.rejectReason ?? Seed.kycRejectReason;
    final others = KycDocType.values.where((d) => d != KycDocType.vehicleRc).toList();

    return Scaffold(
      backgroundColor: RidoColors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DocsHeader(
            title: 'Documents',
            summary: '4 of 5 verified',
            trailing: '1 needs action',
            trailingColor: RidoColors.coral100,
            segments: const [(0.8, RidoColors.success), (0.2, RidoColors.sos)],
            onBack: backOr(context, Routes.documents),
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
                      border: Border.all(color: RidoColors.error),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(RidoSpacing.l),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration:
                                    const BoxDecoration(color: RidoColors.errorTint, borderRadius: RidoRadii.cardRadius),
                                child: const Icon(Symbols.description_rounded, color: RidoColors.error, size: 22),
                              ),
                              const SizedBox(width: RidoSpacing.m),
                              Expanded(child: Text(KycDocType.vehicleRc.label, style: t.bodySemibold)),
                              const IconPill(
                                label: 'Rejected',
                                icon: Symbols.cancel_rounded,
                                bg: RidoColors.errorTint,
                                fg: RidoColors.error,
                              ),
                            ],
                          ),
                        ),
                        Container(
                          color: RidoColors.errorTint,
                          padding: const EdgeInsets.all(RidoSpacing.l),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Semantics(
                                    image: true,
                                    label: 'Your blurry RC photo',
                                    child: Container(
                                      width: 72,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: RidoColors.navy300.withValues(alpha: 0.7),
                                        borderRadius: const BorderRadius.all(Radius.circular(8)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: RidoSpacing.m),
                                  Expanded(child: Text(reason, style: t.body)),
                                ],
                              ),
                              const SizedBox(height: RidoSpacing.l),
                              RidoButton(
                                label: 'Re-upload',
                                icon: Symbols.photo_camera_rounded,
                                onPressed: () => _reupload(context, ref),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: RidoSpacing.l),
                  Container(
                    decoration: BoxDecoration(
                      color: RidoColors.surface,
                      borderRadius: RidoRadii.cardRadius,
                      border: Border.all(color: RidoColors.divider),
                    ),
                    child: Column(
                      children: [
                        for (var i = 0; i < others.length; i++) ...[
                          if (i > 0) const Divider(height: 1),
                          SizedBox(
                            height: 56,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: RidoSpacing.l),
                              child: Row(
                                children: [
                                  const Icon(Symbols.check_circle_rounded, color: RidoColors.success, fill: 1),
                                  const SizedBox(width: RidoSpacing.m),
                                  Expanded(
                                    child: Text(others[i].label,
                                        style: t.body, maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ),
                                  Text('Verified', style: t.bodySmallMedium.copyWith(color: RidoColors.successText)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: RidoSpacing.l),
                  Row(
                    children: [
                      const Icon(Symbols.lightbulb_rounded, size: 18, color: RidoColors.navy500),
                      const SizedBox(width: RidoSpacing.s),
                      Expanded(
                        child: Text('Good light, all 4 corners visible, no glare.',
                            style: t.bodySmall.copyWith(color: RidoColors.navy500)),
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
