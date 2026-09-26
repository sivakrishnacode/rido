import 'package:flutter/material.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

import '../../../common/launch.dart';

/// Server geofence radii (for the early hint only; the API decides and can change them).
const int kPickupRadiusM = 250;
const int kDropRadiusM = 400;

/// "850 m" / "1.2 km".
String formatMetres(int m) => m < 1000 ? '$m m' : '${(m / 1000).toStringAsFixed(1)} km';

/// Runs a job step ([step] gets the far reason, null the first time). When the API answers
/// [ApiException.tooFar], asks the driver why ([TooFarSheet]) and runs it again with the reason.
/// True when the step went through, false when the driver backed out; other errors are rethrown.
Future<bool> runWithFarCheck(
  BuildContext context,
  Future<void> Function(String? farReason) step, {
  required LatLng target,
}) async {
  try {
    await step(null);
    return true;
  } on ApiException catch (e) {
    final far = e.tooFar;
    if (far == null) rethrow;
    if (!context.mounted) return false;
    final reason = await TooFarSheet.show(context, far, target: target);
    if (reason == null) return false;
    await step(reason);
    return true;
  }
}

/// The driver is farther from the pickup / drop than the API allows: the server's message, why it matters,
/// suggested reasons (or "Other" with a 3–200 character note), "Continue anyway" (enabled once a reason is
/// picked) and a shortcut to navigate there. Pops with the reason, or null.
class TooFarSheet extends StatefulWidget {
  const TooFarSheet({super.key, required this.info, required this.target});

  final TooFar info;
  final LatLng target;

  static Future<String?> show(BuildContext context, TooFar info, {required LatLng target}) =>
      showRidoSheet<String>(context, builder: (_) => TooFarSheet(info: info, target: target));

  @override
  State<TooFarSheet> createState() => _TooFarSheetState();
}

class _TooFarSheetState extends State<TooFarSheet> {
  static const _other = 'Other';
  String? _choice;
  final _note = TextEditingController();

  bool get _pickup => widget.info.stop == 'pickup';

  List<String> get _options => [...widget.info.reasons.where((r) => r != _other), _other];

  String? get _reason {
    if (_choice == null) return null;
    if (_choice != _other) return _choice;
    final note = _note.text.trim();
    return note.length >= 3 && note.length <= 200 ? note : null;
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final info = widget.info;
    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: RidoSpacing.s),
        RidoBanner(
          type: RidoBannerType.warning,
          icon: Symbols.wrong_location_rounded,
          title: info.message,
          message: _pickup
              ? 'You need to be within ${formatMetres(info.radiusM)} of the pickup. The passenger may be waiting somewhere else.'
              : 'Trips end within ${formatMetres(info.radiusM)} of the drop. Ending early can lead to fare disputes.',
        ),
        const SizedBox(height: RidoSpacing.l),
        Text(_pickup ? 'Why are you marking arrived here?' : 'Why are you ending here?', style: t.h2),
        const SizedBox(height: RidoSpacing.s),
        ChoiceChips<String>(
          options: _options,
          labelOf: (r) => r,
          selected: {?_choice},
          onChanged: (r) => setState(() => _choice = r),
        ),
        if (_choice == _other) ...[
          const SizedBox(height: RidoSpacing.m),
          RidoTextField(
            label: 'Tell us what happened',
            hint: '3 to 200 characters',
            controller: _note,
            errorText: _note.text.trim().length > 200 ? 'Keep it under 200 characters' : null,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
          ),
        ],
        const SizedBox(height: RidoSpacing.xl),
        RidoButton(
          label: 'Continue anyway',
          onPressed: _reason == null ? null : () => Navigator.of(context).pop(_reason),
        ),
        const SizedBox(height: RidoSpacing.s),
        RidoButton.secondary(
          label: _pickup ? 'Navigate to pickup' : 'Navigate to drop',
          icon: Symbols.near_me_rounded,
          onPressed: () => openNavigation(context, widget.target),
        ),
        const SizedBox(height: RidoSpacing.xs),
        RidoButton.text(label: 'Cancel', expand: true, onPressed: () => Navigator.of(context).pop()),
      ]),
    );
  }
}
