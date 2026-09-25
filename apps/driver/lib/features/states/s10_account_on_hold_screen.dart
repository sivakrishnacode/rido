import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:rido_ui/rido_ui.dart';

import '../../router/routes.dart';
import '../onboarding/widgets/signup_widgets.dart';

/// S-10 Account on hold (temporary): reason and "Contact support".
class S10AccountOnHoldScreen extends StatelessWidget {
  const S10AccountOnHoldScreen({super.key, this.showcase = false});

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: RidoColors.surface,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: RidoColors.navy900,
              child: SafeArea(
                bottom: false,
                child: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(RidoSpacing.l, RidoSpacing.xxl + 16, RidoSpacing.l, RidoSpacing.xl),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Semantics(
                            image: true,
                            label: 'Account paused',
                            child: Center(child: DriverOrb(
                              size: 160,
                              color: RidoColors.warning,
                              child: Stack(
                                clipBehavior: Clip.none,
                                alignment: Alignment.center,
                                children: [
                                  const Icon(Symbols.pause_rounded, size: 80, color: RidoColors.navy900, fill: 1),
                                  Positioned(
                                    top: -52,
                                    right: -52,
                                    child: Container(
                                      width: 14,
                                      height: 14,
                                      decoration: const BoxDecoration(color: RidoColors.coral500, shape: BoxShape.circle),
                                    ),
                                  ),
                                ],
                              ),
                            )),
                          ),
                          const SizedBox(height: RidoSpacing.xl),
                          const Center(child: StatusPill(StatusKind.paused, label: 'On hold')),
                          const SizedBox(height: RidoSpacing.m),
                          Text('Your account is on hold',
                              textAlign: TextAlign.center, style: t.display.copyWith(color: Colors.white)),
                        ],
                      ),
                    ),
                    if (Navigator.of(context).canPop())
                      Positioned(
                        left: RidoSpacing.xs,
                        top: RidoSpacing.s,
                        child: IconButton(
                          tooltip: 'Back',
                          icon: const Icon(Symbols.arrow_back_rounded, color: Colors.white),
                          onPressed: () => context.pop(),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(RidoSpacing.l),
                child: Container(
                  padding: const EdgeInsets.all(RidoSpacing.l),
                  decoration: const BoxDecoration(color: RidoColors.inputBg, borderRadius: RidoRadii.cardRadius),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Symbols.info_rounded, color: RidoColors.navy700),
                      const SizedBox(width: RidoSpacing.m),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Multiple ride complaints under review', style: t.bodySemibold),
                            const SizedBox(height: 2),
                            Text("You can't go online until the review is complete. Your plan days are paused, not lost.",
                                style: t.bodySmall.copyWith(color: RidoColors.navy700)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            BottomActions(
              children: [
                RidoButton(
                  label: 'Contact support',
                  icon: Symbols.support_agent_rounded,
                  onPressed: () => context.push(Routes.help),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
