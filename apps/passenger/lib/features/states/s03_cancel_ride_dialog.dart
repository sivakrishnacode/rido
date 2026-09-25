import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rido_ui/rido_ui.dart';

import '../../state/ride_flow.dart';

/// S-03 Cancel ride: reason list, red "Cancel ride" (enabled once a reason is picked) and "Keep ride".
/// Pops with the chosen reason, or null to keep the ride.
class S03CancelRideDialog extends ConsumerStatefulWidget {
  const S03CancelRideDialog({super.key, this.showcase = false});

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  static const reasons = ['Driver too far', 'Changed my plan', 'Booked by mistake', 'Other'];

  /// Opens the dialog. Returns the reason when the passenger confirms, null to keep the ride.
  static Future<String?> show(BuildContext context) =>
      showDialog<String>(context: context, builder: (_) => const S03CancelRideDialog());

  @override
  ConsumerState<S03CancelRideDialog> createState() => _S03CancelRideDialogState();
}

class _S03CancelRideDialogState extends ConsumerState<S03CancelRideDialog> {
  late String? _reason = widget.showcase ? 'Changed my plan' : null;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final ride = ref.watch(rideFlowProvider);
    final name = ride.driver.firstName;
    final message = ride.phase == RidePhase.arrived
        ? '$name is waiting at your pickup. Tell us why:'
        : '$name is ${ride.etaMin < 1 ? 1 : ride.etaMin} min away. Tell us why:';
    return RidoDialog(
      title: 'Cancel this ride?',
      message: message,
      content: Column(
        children: [
          for (final r in S03CancelRideDialog.reasons)
            Semantics(
              selected: r == _reason,
              button: true,
              child: InkWell(
                onTap: () => setState(() => _reason = r),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 48),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: RidoColors.divider))),
                  child: Row(
                    children: [
                      Icon(
                        r == _reason ? Symbols.radio_button_checked_rounded : Symbols.radio_button_unchecked_rounded,
                        color: r == _reason ? RidoColors.coral600 : RidoColors.navy500,
                        size: 24,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(r, style: r == _reason ? t.bodySemibold : t.body),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      actions: [
        RidoButton.danger(
          label: 'Cancel ride',
          onPressed: _reason == null ? null : () => Navigator.of(context).maybePop(_reason),
        ),
        const SizedBox(height: 4),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: RidoColors.navy900),
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Text('Keep ride'),
        ),
      ],
    );
  }
}
