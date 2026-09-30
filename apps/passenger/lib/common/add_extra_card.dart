import 'package:flutter/material.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';
import 'package:tamiltaxi_ui/tamiltaxi_ui.dart';

/// P-12 / PP-07 after a while with no driver (like Rapido's): add a little extra on top of the fare so more drivers
/// take it. Pick +₹10 / +₹20 / +₹30, then "Add ₹20 · ₹70 in all" sends it ([onAdd] gets the new extra in all). It all
/// goes to the driver; drivers see "₹50 + ₹20".
class AddExtraCard extends StatefulWidget {
  const AddExtraCard({
    super.key,
    required this.total,
    required this.extra,
    required this.busy,
    required this.onAdd,
  });

  /// The fare now, the [extra] included.
  final int total;

  /// Added so far (0 = none yet).
  final int extra;
  final bool busy;
  final ValueChanged<int> onAdd;

  @override
  State<AddExtraCard> createState() => _AddExtraCardState();
}

class _AddExtraCardState extends State<AddExtraCard> {
  int? _step;

  @override
  void didUpdateWidget(AddExtraCard old) {
    super.didUpdateWidget(old);
    // Added: pick again for more.
    if (old.extra != widget.extra) _step = null;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final base = widget.total - widget.extra;
    final room = FareEngine.maxExtra(base) - widget.extra;
    final steps = [for (final s in FareEngine.extraSteps) if (s <= room) s];
    final step = _step;
    return TtCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Symbols.add_card_rounded, color: TtColors.success, fill: 1, size: 26),
          const SizedBox(width: TtSpacing.m),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                widget.extra == 0 ? 'No driver yet? Add a little extra' : '${formatInr(widget.extra)} extra added',
                style: t.bodySemibold,
              ),
              Text(
                widget.extra == 0
                    ? 'It all goes to the driver, and drivers who passed see it again.'
                    : 'Drivers now see ${formatInr(base)} + ${formatInr(widget.extra)}.'
                        '${steps.isEmpty ? " That's the most you can add." : ' Add more?'}',
                style: t.caption,
              ),
            ]),
          ),
        ]),
        if (steps.isNotEmpty) ...[
          const SizedBox(height: TtSpacing.m),
          Wrap(spacing: TtSpacing.s, runSpacing: TtSpacing.s, children: [
            for (final s in steps)
              TtChip(
                label: '+${formatInr(s)}',
                selected: step == s,
                onTap: widget.busy ? null : () => setState(() => _step = step == s ? null : s),
              ),
          ]),
          if (step != null) ...[
            const SizedBox(height: TtSpacing.m),
            TtButton(
              label: 'Add ${formatInr(step)} · ${formatInr(widget.total + step)} in all',
              height: 48,
              loading: widget.busy,
              onPressed: () => widget.onAdd(widget.extra + step),
            ),
          ],
        ],
      ]),
    );
  }
}
