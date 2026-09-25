import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

import '../../state/driver_account.dart';

/// D-08 Upload document (simulated camera). D-08a: card guide, Front / Back side,
/// "Take photo". D-08b: a captured placeholder card with "Retake" and "Use photo"
/// ("Use photo" marks the document Under review, then Verified after 3 s, and goes back).
class D08UploadDocumentScreen extends ConsumerStatefulWidget {
  const D08UploadDocumentScreen({super.key, this.type = KycDocType.insurance, this.captured = false, this.showcase = false});

  final KycDocType type;

  /// Start in the captured state (D-08b).
  final bool captured;

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  @override
  ConsumerState<D08UploadDocumentScreen> createState() => _D08UploadDocumentScreenState();
}

class _D08UploadDocumentScreenState extends ConsumerState<D08UploadDocumentScreen> {
  late bool _captured = widget.captured;
  bool _back = false;
  bool _flash = false;
  bool _submitting = false;

  String get _noun => switch (widget.type) {
        KycDocType.drivingLicence => 'licence',
        KycDocType.aadhaar => 'Aadhaar card',
        KycDocType.vehicleRc => 'RC',
        KycDocType.insurance => 'policy page',
        KycDocType.policeVerification => 'certificate',
      };

  Future<void> _use() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    await ref.read(kycProvider.notifier).upload(widget.type);
    if (!mounted) return;
    showRidoSnack(context, '${widget.type.label} uploaded. We\'re reviewing it.', success: true);
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final side = _back ? 'back' : 'front';
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 64,
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Close',
                      icon: const Icon(Symbols.close_rounded, color: Colors.white),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    Expanded(
                      child: Text(widget.type.label,
                          style: t.h1.copyWith(color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    IconButton(
                      tooltip: _flash ? 'Flash on' : 'Flash off',
                      icon: Icon(_flash ? Symbols.flash_on_rounded : Symbols.flash_off_rounded, color: Colors.white),
                      onPressed: () => setState(() => _flash = !_flash),
                    ),
                  ],
                ),
              ),
              Center(child: _sideToggle(t)),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, c) {
                    final w = c.maxWidth - 2 * RidoSpacing.l;
                    final h = (w * 0.63).clamp(120.0, c.maxHeight * 0.55);
                    return Container(
                      decoration: _captured
                          ? null
                          : const BoxDecoration(
                              gradient: RadialGradient(
                                radius: 0.9,
                                colors: [RidoColors.navy700, RidoColors.navy900, Colors.black],
                                stops: [0, 0.45, 1],
                              ),
                            ),
                      child: SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: c.maxHeight),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _Frame(
                                width: w,
                                height: h,
                                color: _captured ? RidoColors.coral500 : Colors.white,
                                child: _captured
                                    ? _CapturedCard(type: widget.type, back: _back)
                                    : Container(
                                        decoration: BoxDecoration(
                                          color: RidoColors.navy700.withValues(alpha: 0.5),
                                          borderRadius: RidoRadii.cardRadius,
                                        ),
                                        child: const Center(
                                          child: Icon(Symbols.crop_free_rounded, color: RidoColors.navy300, size: 44),
                                        ),
                                      ),
                              ),
                              const SizedBox(height: RidoSpacing.l),
                              if (_captured) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration:
                                      const BoxDecoration(color: RidoColors.success, borderRadius: RidoRadii.pillRadius),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Symbols.check_circle_rounded, color: Colors.white, fill: 1, size: 20),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text('Looks clear · all corners visible',
                                            style: t.bodySmallMedium.copyWith(color: Colors.white)),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: RidoSpacing.m),
                                Text(
                                  _back ? 'Back side captured.' : 'Now: front side. Add the back side if it has details.',
                                  textAlign: TextAlign.center,
                                  style: t.body.copyWith(color: RidoColors.navy300),
                                ),
                              ] else ...[
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: RidoSpacing.xl),
                                  child: Text(
                                    'Place the $side of your $_noun inside the frame',
                                    textAlign: TextAlign.center,
                                    style: t.bodySemibold.copyWith(color: RidoColors.navy300),
                                  ),
                                ),
                                const SizedBox(height: RidoSpacing.m),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: RidoColors.navy700.withValues(alpha: 0.6),
                                    borderRadius: RidoRadii.pillRadius,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Symbols.light_mode_rounded, color: RidoColors.navy300, size: 18),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text('Good light · no glare · all 4 corners',
                                            style: t.bodySmall.copyWith(color: RidoColors.navy300)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (_captured) _capturedActions() else _cameraBar(t),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sideToggle(RidoTextStyles t) {
    Widget seg(String label, bool selected, VoidCallback onTap) => Semantics(
          selected: selected,
          button: true,
          child: Material(
            color: selected ? Colors.white : Colors.transparent,
            shape: const StadiumBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Container(
                width: 120,
                height: 40,
                alignment: Alignment.center,
                child: Text(label,
                    style: t.bodySemibold.copyWith(color: selected ? RidoColors.navy900 : RidoColors.navy300)),
              ),
            ),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: const BoxDecoration(color: RidoColors.navy900, borderRadius: RidoRadii.pillRadius),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          seg('Front side', !_back, () => setState(() {
                _back = false;
                _captured = false;
              })),
          seg('Back side', _back, () => setState(() {
                _back = true;
                _captured = false;
              })),
        ],
      ),
    );
  }

  Widget _cameraBar(RidoTextStyles t) => Container(
        color: Colors.black,
        padding: const EdgeInsets.fromLTRB(RidoSpacing.l, RidoSpacing.l, RidoSpacing.l, RidoSpacing.l),
        child: Row(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Semantics(
                  button: true,
                  label: 'Choose from gallery',
                  excludeSemantics: true,
                  child: InkWell(
                    borderRadius: RidoRadii.cardRadius,
                    onTap: () {
                      setState(() => _captured = true);
                      showRidoSnack(context, 'Photo picked from gallery');
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: const BoxDecoration(color: RidoColors.navy900, borderRadius: RidoRadii.cardRadius),
                          child: const Icon(Symbols.photo_library_rounded, color: RidoColors.navy300),
                        ),
                        const SizedBox(height: 4),
                        Text('Gallery', style: t.caption.copyWith(color: RidoColors.navy300)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Semantics(
              button: true,
              label: 'Take photo',
              excludeSemantics: true,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => setState(() => _captured = true),
                child: Container(
                  width: 80,
                  height: 80,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: RidoColors.navy300, width: 4),
                  ),
                  child: const DecoratedBox(decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                ),
              ),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: Text('Step ${_back ? 2 : 1}/2', style: t.bodySmallMedium.copyWith(color: RidoColors.navy300)),
              ),
            ),
          ],
        ),
      );

  Widget _capturedActions() => Padding(
        padding: const EdgeInsets.fromLTRB(RidoSpacing.l, RidoSpacing.m, RidoSpacing.l, RidoSpacing.m),
        child: Row(
          children: [
            Expanded(
              child: Material(
                color: Colors.transparent,
                shape: const StadiumBorder(side: BorderSide(color: Colors.white, width: 1.5)),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: _submitting ? null : () => setState(() => _captured = false),
                  child: SizedBox(
                    height: 52,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Symbols.refresh_rounded, color: Colors.white),
                        const SizedBox(width: 8),
                        Text('Retake', style: context.type.button.copyWith(color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: RidoSpacing.m),
            Expanded(child: RidoButton(label: 'Use photo', loading: _submitting, onPressed: _use)),
          ],
        ),
      );
}

/// Four corner brackets around [child].
class _Frame extends StatelessWidget {
  const _Frame({required this.width, required this.height, required this.color, required this.child});

  final double width;
  final double height;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    const arm = 36.0;
    const stroke = 4.0;
    BorderSide s() => BorderSide(color: color, width: stroke);
    Widget corner({required bool top, required bool left}) => Positioned(
          top: top ? 0 : null,
          bottom: top ? null : 0,
          left: left ? 0 : null,
          right: left ? null : 0,
          child: Container(
            width: arm,
            height: arm,
            decoration: BoxDecoration(
              border: Border(
                top: top ? s() : BorderSide.none,
                bottom: top ? BorderSide.none : s(),
                left: left ? s() : BorderSide.none,
                right: left ? BorderSide.none : s(),
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(top && left ? 10 : 0),
                topRight: Radius.circular(top && !left ? 10 : 0),
                bottomLeft: Radius.circular(!top && left ? 10 : 0),
                bottomRight: Radius.circular(!top && !left ? 10 : 0),
              ),
            ),
          ),
        );
    return SizedBox(
      width: width + 16,
      height: height + 16,
      child: Stack(
        children: [
          Positioned.fill(child: Padding(padding: const EdgeInsets.all(8), child: child)),
          corner(top: true, left: true),
          corner(top: true, left: false),
          corner(top: false, left: true),
          corner(top: false, left: false),
        ],
      ),
    );
  }
}

/// A placeholder photo of the document: header strip, a greyed photo and blurred detail bars.
class _CapturedCard extends StatelessWidget {
  const _CapturedCard({required this.type, required this.back});

  final KycDocType type;
  final bool back;

  (String, String) get _header => switch (type) {
        KycDocType.drivingLicence => ('INDIAN UNION DRIVING LICENCE', 'TAMIL NADU'),
        KycDocType.aadhaar => ('AADHAAR · GOVERNMENT OF INDIA', 'UIDAI'),
        KycDocType.vehicleRc => ('CERTIFICATE OF REGISTRATION', 'TAMIL NADU'),
        KycDocType.insurance => ('MOTOR INSURANCE POLICY', 'TWO-WHEELER'),
        KycDocType.policeVerification => ('POLICE CLEARANCE CERTIFICATE', 'TN POLICE'),
      };

  String get _firstLabel => switch (type) {
        KycDocType.drivingLicence => 'DL No:',
        KycDocType.aadhaar => 'Aadhaar No:',
        KycDocType.vehicleRc => 'Reg No:',
        KycDocType.insurance => 'Policy No:',
        KycDocType.policeVerification => 'Cert No:',
      };

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final (left, right) = _header;
    Widget bar(double f) => FractionallySizedBox(
          widthFactor: f,
          alignment: Alignment.centerLeft,
          child: Container(
            height: 10,
            margin: const EdgeInsets.symmetric(vertical: 5),
            decoration: const BoxDecoration(color: RidoColors.navy300, borderRadius: RidoRadii.pillRadius),
          ),
        );
    return Semantics(
      image: true,
      label: 'Captured photo of your ${type.label}, personal details hidden',
      child: Container(
        decoration: const BoxDecoration(color: RidoColors.divider, borderRadius: RidoRadii.cardRadius),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: RidoColors.navy700,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(back ? '$left · BACK' : left,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.overline.copyWith(color: Colors.white)),
                  ),
                  Text(right, style: t.overline.copyWith(color: Colors.white)),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!back) ...[
                      AspectRatio(
                        aspectRatio: 0.8,
                        child: Container(
                          decoration: BoxDecoration(
                            color: RidoColors.navy500.withValues(alpha: 0.55),
                            borderRadius: const BorderRadius.all(Radius.circular(8)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: ClipRect(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(_firstLabel, style: t.caption.copyWith(fontWeight: FontWeight.w700)),
                                const SizedBox(width: 6),
                                Expanded(child: bar(0.9)),
                              ],
                            ),
                            bar(0.95),
                            bar(0.7),
                            bar(0.85),
                            if (type == KycDocType.drivingLicence)
                              Text('Valid till: ▒▒▒▒ · MCWG, LMV',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: t.caption.copyWith(fontWeight: FontWeight.w600))
                            else
                              bar(0.6),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
