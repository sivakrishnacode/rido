import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';
import 'package:tamiltaxi_ui/tamiltaxi_ui.dart';

import '../../state/ride_flow.dart';

/// S-03 Cancel ride: reason list ([CancelCode.forPassenger]), red "Cancel ride" (enabled once a reason is picked) and
/// "Keep ride". Pops with the chosen code (sent to the API), or null to keep the ride.
class S03CancelRideDialog extends ConsumerStatefulWidget {
  const S03CancelRideDialog({super.key, this.showcase = false});

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  static const reasons = CancelCode.forPassenger;

  /// Opens the dialog. Returns the reason code when the passenger confirms, null to keep the ride.
  static Future<CancelCode?> show(BuildContext context) =>
      showDialog<CancelCode>(context: context, builder: (_) => const S03CancelRideDialog());

  @override
  ConsumerState<S03CancelRideDialog> createState() => _S03CancelRideDialogState();
}

class _S03CancelRideDialogState extends ConsumerState<S03CancelRideDialog> {
  late CancelCode? _reason = widget.showcase ? CancelCode.changedMind : null;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final ride = ref.watch(rideFlowProvider);
    final name = ride.driver.firstName;
    final message = ride.phase == RidePhase.arrived
        ? '$name is waiting at your pickup. Tell us why:'
        : '$name is ${ride.etaMin < 1 ? 1 : ride.etaMin} min away. Tell us why:';
    return TtDialog(
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
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: TtColors.divider))),
                  child: Row(
                    children: [
                      Icon(
                        r == _reason ? Symbols.radio_button_checked_rounded : Symbols.radio_button_unchecked_rounded,
                        color: r == _reason ? TtColors.coral600 : TtColors.navy500,
                        size: 24,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(r.label, style: r == _reason ? t.bodySemibold : t.body),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      actions: [
        TtButton.danger(
          label: 'Cancel ride',
          onPressed: _reason == null ? null : () => Navigator.of(context).maybePop(_reason),
        ),
        const SizedBox(height: 4),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: TtColors.navy900),
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Text('Keep ride'),
        ),
      ],
    );
  }
}
