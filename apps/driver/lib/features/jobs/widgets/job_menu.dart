import 'package:flutter/material.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';
import 'package:tamiltaxi_ui/tamiltaxi_ui.dart';

/// The job screens' ⋮ menu (D-16, D-21): Help and Cancel. [cancelLabel]: "Cancel ride" / "Cancel delivery".
class JobMoreMenu extends StatelessWidget {
  const JobMoreMenu({
    super.key,
    required this.onHelp,
    required this.onCancel,
    this.cancelLabel = 'Cancel ride',
  });

  final VoidCallback onHelp;

  /// Null: no Cancel (after the pickup).
  final VoidCallback? onCancel;
  final String cancelLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return PopupMenuButton<String>(
      tooltip: 'More options',
      icon: Container(
        width: 48,
        height: 48,
        decoration: const BoxDecoration(
          color: TtColors.navy700,
          shape: BoxShape.circle,
        ),
        child: const Icon(Symbols.more_vert_rounded, color: Colors.white),
      ),
      color: TtColors.surface,
      shape: RoundedRectangleBorder(borderRadius: TtRadii.cardRadius),
      position: PopupMenuPosition.under,
      onSelected: (v) => v == 'help' ? onHelp() : onCancel?.call(),
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'help',
          height: 56,
          child: Row(
            children: [
              const Icon(
                Symbols.support_agent_rounded,
                color: TtColors.navy700,
              ),
              const SizedBox(width: TtSpacing.m),
              Text('Help', style: t.body),
            ],
          ),
        ),
        if (onCancel != null)
          PopupMenuItem(
            value: 'cancel',
            height: 56,
            child: Row(
              children: [
                const Icon(Symbols.cancel_rounded, color: TtColors.error),
                const SizedBox(width: TtSpacing.m),
                Text(
                  cancelLabel,
                  style: t.body.copyWith(color: TtColors.error),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Radio list of cancel reasons. Returns the chosen code, or null for "Keep …".
class CancelReasonDialog extends StatefulWidget {
  const CancelReasonDialog({
    super.key,
    required this.reasons,
    this.noun = 'ride',
  });
  final List<CancelCode> reasons;

  /// "ride" or "delivery", for the buttons.
  final String noun;

  /// Shows the dialog; the chosen reason, or null.
  static Future<CancelCode?> show(
    BuildContext context, {
    required List<CancelCode> reasons,
    String noun = 'ride',
  }) => showDialog<CancelCode>(
    context: context,
    builder: (_) => CancelReasonDialog(reasons: reasons, noun: noun),
  );

  @override
  State<CancelReasonDialog> createState() => _CancelReasonDialogState();
}

class _CancelReasonDialogState extends State<CancelReasonDialog> {
  CancelCode? _reason;

  @override
  Widget build(BuildContext context) => TtDialog(
    title: 'Why are you cancelling?',
    message: 'Frequent cancellations can lower your rating.',
    icon: Symbols.cancel_rounded,
    destructive: true,
    content: RadioGroup<CancelCode>(
      groupValue: _reason,
      onChanged: (v) => setState(() => _reason = v),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final r in widget.reasons)
            RadioListTile<CancelCode>(
              value: r,
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(r.label, style: context.type.body),
            ),
        ],
      ),
    ),
    actions: [
      TtButton.danger(
        label: 'Cancel ${widget.noun}',
        onPressed: _reason == null
            ? null
            : () => Navigator.of(context).pop(_reason),
      ),
      const SizedBox(height: TtSpacing.xs),
      TtButton.text(
        label: 'Keep ${widget.noun}',
        expand: true,
        onPressed: () => Navigator.of(context).pop(),
      ),
    ],
  );
}
