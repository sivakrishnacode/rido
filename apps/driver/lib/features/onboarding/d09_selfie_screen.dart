import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tamiltaxi_ui/tamiltaxi_ui.dart';

import '../../router/routes.dart';
import '../../state/driver_session.dart';
import '../../state/live_helpers.dart';
import 'widgets/signup_widgets.dart';

/// D-09 Selfie verification: circular face guide and "Take selfie".
/// Sign-up → D-10 Under review. [dailyCheck] (from S-13) → marks the check done, goes online.
class D09SelfieScreen extends ConsumerStatefulWidget {
  const D09SelfieScreen({super.key, this.dailyCheck = false, this.showcase = false});

  /// Opened from S-13 before going online.
  final bool dailyCheck;

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  @override
  ConsumerState<D09SelfieScreen> createState() => _D09SelfieScreenState();
}

class _D09SelfieScreenState extends ConsumerState<D09SelfieScreen> {
  static const _captureTime = Duration(milliseconds: 800);
  Timer? _timer;
  bool _capturing = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _take() {
    if (_capturing) return;
    setState(() => _capturing = true);
    _timer = Timer(_captureTime, () {
      if (!mounted) return;
      setState(() => _capturing = false);
      if (widget.dailyCheck) {
        _goOnline();
      } else {
        context.go(Routes.documents);
      }
    });
  }

  /// S-13 daily check done → online. Live API: going online can still fail (GPS off, plan expired);
  /// the reason shows on Home.
  Future<void> _goOnline() async {
    final session = ref.read(driverSessionProvider.notifier);
    session.markSelfieDone();
    String? error;
    try {
      await session.goOnline();
    } on Exception catch (e) {
      error = userMessage(e);
    }
    if (!mounted) return;
    context.go(Routes.home);
    showTtSnack(context, error ?? "Selfie verified. You're online", success: error == null);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: TtColors.navy900,
        appBar: SignupAppBar(
          title: widget.dailyCheck ? 'Selfie check' : 'Selfie verification',
          onBack: widget.dailyCheck ? null : backOr(context, Routes.documents),
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) {
                  final d = (c.maxWidth * 0.74).clamp(140.0, (c.maxHeight - 150).clamp(140.0, 300.0));
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: c.maxHeight),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: TtSpacing.l),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Semantics(
                              image: true,
                              label: 'Face guide',
                              child: DashedRing(
                                size: d,
                                color: _capturing ? TtColors.success : TtColors.coral500,
                                strokeWidth: 4,
                                child: Container(
                                  width: d - 20,
                                  height: d - 20,
                                  decoration: const BoxDecoration(color: TtColors.navy700, shape: BoxShape.circle),
                                  child: _capturing
                                      ? const Center(
                                          child: SizedBox(
                                            width: 40,
                                            height: 40,
                                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                                          ),
                                        )
                                      : Icon(Symbols.face_rounded, size: d * 0.6, color: TtColors.navy500, fill: 0),
                                ),
                              ),
                            ),
                            const SizedBox(height: TtSpacing.xl),
                            Text(
                              _capturing ? 'Hold still…' : 'Look straight, remove helmet or cap',
                              textAlign: TextAlign.center,
                              style: t.h1.copyWith(color: Colors.white),
                            ),
                            const SizedBox(height: TtSpacing.s),
                            Text('Keep your face inside the circle, in good light.',
                                textAlign: TextAlign.center, style: t.body.copyWith(color: TtColors.navy300)),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            BottomActions(
              children: [
                TtButton(
                  label: _capturing ? 'Capturing…' : 'Take selfie',
                  icon: Symbols.photo_camera_rounded,
                  loading: _capturing,
                  onPressed: _take,
                ),
                const SizedBox(height: TtSpacing.m),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Symbols.verified_user_rounded, size: 18, color: TtColors.navy300),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text('We match this with your documents to keep riders safe.',
                          style: t.caption.copyWith(color: TtColors.navy300)),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
