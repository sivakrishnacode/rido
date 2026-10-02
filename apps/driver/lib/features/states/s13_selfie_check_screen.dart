import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';
import 'package:tamiltaxi_ui/tamiltaxi_ui.dart';

import '../../common/camera.dart';
import '../../common/go_online.dart';
import '../../router/routes.dart';
import '../../state/driver_session.dart';
import '../../state/live_helpers.dart';
import '../onboarding/widgets/signup_widgets.dart';

/// S-13 Selfie check before going online: a panel over the dimmed home map with "Take selfie".
///
/// Live API: the server asks for it (403 `SELFIE_CHECK_REQUIRED` when going online). Take selfie opens the front
/// camera; the photo goes to `POST /drivers/me/selfie-check`, which matches it with the selfie from the identity
/// check, and a pass goes online ([goOnlineOrExplain]). No match or not exactly one face (422) shows the reason with
/// Retake. Mock mode: the simulated D-09 camera, once per app session.
class S13SelfieCheckScreen extends ConsumerStatefulWidget {
  const S13SelfieCheckScreen({super.key, this.showcase = false});

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  @override
  ConsumerState<S13SelfieCheckScreen> createState() => _S13SelfieCheckScreenState();
}

class _S13SelfieCheckScreenState extends ConsumerState<S13SelfieCheckScreen> {
  late final bool _live = !widget.showcase && ref.read(isLiveApiProvider);
  bool _busy = false;
  String? _error;
  Uint8List? _photo;

  Future<void> _take() async {
    if (_busy) return;
    if (widget.showcase) {
      showTtSnack(context, 'Design preview: the camera opens here');
      return;
    }
    if (!_live) {
      context.push(Routes.dailySelfie);
      return;
    }
    TakenPhoto? photo;
    try {
      photo = await ref.read(photoCameraProvider)(front: true);
    } catch (_) {
      if (mounted) showTtSnack(context, 'Allow camera access to take your selfie');
      return;
    }
    if (photo == null || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
      _photo = photo!.bytes;
    });
    try {
      await ref.read(liveJobsProvider).selfieCheck(photo.bytes, photo.name);
    } on ApiException catch (e) {
      // 422: no match, no face or several faces (retake); 409: no selfie from the identity check yet; 429: too many
      // tries today. The server's message says which.
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.message;
        });
      }
      return;
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showTtSnack(context, userMessage(e));
      }
      return;
    }
    if (!mounted) return;
    ref.read(driverSessionProvider.notifier).markSelfieDone();
    await goOnlineOrExplain(context, ref, toHome: true, onlineMessage: "Selfie verified. You're online");
  }

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    void close() => Navigator.of(context).maybePop();
    // Behind the panel: where the driver is (the last fix, or the demo car), else the first service city.
    final session = ref.read(driverSessionProvider.notifier);
    final center = session.position ?? session.vehicle.value?.position ?? CityDefaults.center;
    final photo = _photo;
    final error = _error;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: TtColors.navy900,
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
                      child: TtMap(
                        center: center,
                        interactive: false,
                        showAttribution: false,
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: _busy ? null : close,
                      child: const ColoredBox(color: TtColors.scrim),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Material(
                      color: TtColors.surface,
                      borderRadius: TtRadii.sheetTop,
                      child: SafeArea(
                        top: false,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(TtSpacing.l, 0, TtSpacing.l, TtSpacing.m),
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
                                        color: error != null ? TtColors.error : TtColors.coral500,
                                        child: Container(
                                          width: 160,
                                          height: 160,
                                          clipBehavior: Clip.antiAlias,
                                          decoration:
                                              const BoxDecoration(color: TtColors.navy900, shape: BoxShape.circle),
                                          child: photo != null
                                              ? Image.memory(photo, fit: BoxFit.cover, gaplessPlayback: true)
                                              : const Icon(Symbols.face_rounded, size: 96, color: TtColors.navy500),
                                        ),
                                      ),
                                      Positioned(
                                        right: 4,
                                        bottom: 8,
                                        child: Container(
                                          width: 48,
                                          height: 48,
                                          decoration: BoxDecoration(
                                            color: TtColors.coral500,
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
                              const SizedBox(height: TtSpacing.l),
                              Text(_busy ? 'Checking your selfie…' : 'Quick selfie check',
                                  textAlign: TextAlign.center, style: t.h1),
                              const SizedBox(height: TtSpacing.xs),
                              Text('We match it with your ID check selfie',
                                  textAlign: TextAlign.center, style: t.body.copyWith(color: TtColors.navy700)),
                              if (error != null) ...[
                                const SizedBox(height: TtSpacing.m),
                                Container(
                                  padding: const EdgeInsets.all(TtSpacing.m),
                                  decoration: const BoxDecoration(color: TtColors.errorTint, borderRadius: TtRadii.cardRadius),
                                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    const Icon(Symbols.error_rounded, color: TtColors.error, size: 20, fill: 1),
                                    const SizedBox(width: TtSpacing.s),
                                    Expanded(child: Text(error, style: t.bodySmall.copyWith(color: TtColors.navy900))),
                                  ]),
                                ),
                              ],
                              const SizedBox(height: TtSpacing.l),
                              TtButton(
                                label: error != null ? 'Retake selfie' : 'Take selfie',
                                icon: Symbols.photo_camera_rounded,
                                loading: _busy,
                                onPressed: _busy ? null : _take,
                              ),
                              const SizedBox(height: TtSpacing.s),
                              Text(
                                  error != null
                                      ? 'Face the light, no cap, helmet or sunglasses'
                                      : 'Takes about 10 seconds · asked once a day',
                                  textAlign: TextAlign.center,
                                  style: t.caption.copyWith(color: TtColors.navy500)),
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
