import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

import '../../router/routes.dart';
import '../onboarding/widgets/signup_widgets.dart';

/// S-13 Selfie check before going online: a panel over the dimmed home map with
/// "Take selfie" → the D-09 camera (daily check).
class S13SelfieCheckScreen extends StatelessWidget {
  const S13SelfieCheckScreen({super.key, this.showcase = false});

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    void close() => Navigator.of(context).maybePop();
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: RidoColors.navy900,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SafeArea(
              bottom: false,
              child: SizedBox(
                height: 64,
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Back',
                      icon: const Icon(Symbols.arrow_back_rounded, color: Colors.white),
                      onPressed: close,
                    ),
                    Expanded(
                      child: Text('Before you go online', style: t.h2.copyWith(color: Colors.white)),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ExcludeSemantics(
                      child: RidoMap(
                        center: Seed.gandhipuram.location,
                        interactive: false,
                        showAttribution: false,
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: close,
                      child: const ColoredBox(color: RidoColors.scrim),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Material(
                      color: RidoColors.surface,
                      borderRadius: RidoRadii.sheetTop,
                      child: SafeArea(
                        top: false,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(RidoSpacing.l, 0, RidoSpacing.l, RidoSpacing.m),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SheetHandle(),
                              Center(
                                child: SizedBox(
                                  width: 176,
                                  height: 176,
                                  child: Stack(
                                    children: [
                                      DashedRing(
                                        size: 176,
                                        strokeWidth: 3,
                                        child: Container(
                                          width: 160,
                                          height: 160,
                                          decoration:
                                              const BoxDecoration(color: RidoColors.navy900, shape: BoxShape.circle),
                                          child: const Icon(Symbols.face_rounded, size: 96, color: RidoColors.navy500),
                                        ),
                                      ),
                                      Positioned(
                                        right: 4,
                                        bottom: 8,
                                        child: Container(
                                          width: 48,
                                          height: 48,
                                          decoration: BoxDecoration(
                                            color: RidoColors.coral500,
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.white, width: 4),
                                          ),
                                          child: const Icon(Symbols.photo_camera_rounded,
                                              color: Colors.white, fill: 1, size: 22),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: RidoSpacing.l),
                              Text('Quick selfie check', textAlign: TextAlign.center, style: t.h1),
                              const SizedBox(height: RidoSpacing.xs),
                              Text("We verify it's you to keep riders safe",
                                  textAlign: TextAlign.center, style: t.body.copyWith(color: RidoColors.navy700)),
                              const SizedBox(height: RidoSpacing.l),
                              RidoButton(label: 'Take selfie', onPressed: () => context.push(Routes.dailySelfie)),
                              const SizedBox(height: RidoSpacing.s),
                              Text('Takes about 10 seconds · asked once a day',
                                  textAlign: TextAlign.center, style: t.caption.copyWith(color: RidoColors.navy500)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
