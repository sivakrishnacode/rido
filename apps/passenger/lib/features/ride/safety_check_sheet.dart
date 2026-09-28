import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

/// What the passenger chose on the safety check sheet.
enum SafetyAnswer { ok, help }

/// "Is everything OK?" (a long stop or a route change during the ride) or "Did you reach safely?" (after a night
/// ride): I'm OK / Get help. The answer goes to the API (`POST /trips/:id/safety-check`); "Get help" raises an SOS
/// there and the caller opens the SOS screen (P-17), even if the call failed (it has the offline options).
class SafetyCheckSheet extends ConsumerStatefulWidget {
  const SafetyCheckSheet({super.key, required this.check});
  final SafetyCheck check;

  /// Shows the sheet; the answer, or null when dismissed.
  static Future<SafetyAnswer?> show(BuildContext context, SafetyCheck check) =>
      showRidoSheet<SafetyAnswer>(context, builder: (_) => SafetyCheckSheet(check: check));

  @override
  ConsumerState<SafetyCheckSheet> createState() => _SafetyCheckSheetState();
}

class _SafetyCheckSheetState extends ConsumerState<SafetyCheckSheet> {
  SafetyAnswer? _sending;

  Future<void> _answer(SafetyAnswer answer) async {
    if (_sending != null) return;
    setState(() => _sending = answer);
    final navigator = Navigator.of(context);
    try {
      await ref.read(liveSafetyProvider).answer(widget.check, ok: answer == SafetyAnswer.ok);
    } catch (_) {
      // "I'm OK" that didn't reach the server changes nothing; "Get help" still opens the SOS screen.
    }
    if (mounted) navigator.pop(answer);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final check = widget.check;
    final title = check.title.isNotEmpty ? check.title : (check.isArrival ? 'Did you reach safely?' : 'Is everything OK?');
    final message = check.message.isNotEmpty
        ? check.message
        : check.isArrival
            ? 'Let us know you got home safely.'
            : 'Your ride seems to have stopped or changed route.';
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: RidoColors.sos.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: const Icon(Symbols.shield_rounded, fill: 1, color: RidoColors.sos),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(title, style: t.h1)),
        ]),
        const SizedBox(height: 12),
        Text(message, style: t.body.copyWith(color: RidoColors.navy700)),
        const SizedBox(height: 20),
        RidoButton(
          key: const ValueKey('safety-ok'),
          label: check.isArrival ? "Yes, I'm safe" : "I'm OK",
          icon: Symbols.check_circle_rounded,
          loading: _sending == SafetyAnswer.ok,
          onPressed: _sending == null ? () => _answer(SafetyAnswer.ok) : null,
        ),
        const SizedBox(height: 12),
        RidoButton.danger(
          key: const ValueKey('safety-help'),
          label: check.isArrival ? 'No, I need help' : 'Get help',
          icon: Symbols.sos_rounded,
          loading: _sending == SafetyAnswer.help,
          onPressed: _sending == null ? () => _answer(SafetyAnswer.help) : null,
        ),
      ],
    );
  }
}
