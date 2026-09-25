import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rido_ui/rido_ui.dart';

import '../../state/ride_flow.dart';

/// P-11 Fare details (bottom sheet over P-10): itemised fare for the selected vehicle.
class P11FareDetailsSheet extends ConsumerWidget {
  const P11FareDetailsSheet({super.key, this.showcase = false});

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  /// Opens the sheet over the current screen.
  static Future<void> show(BuildContext context) =>
      showRidoSheet<void>(context, builder: (_) => const P11FareDetailsSheet());

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.type;
    final state = ref.watch(rideFlowProvider);
    final q = state.quote;
    String short(String name) => name.split(' ').first;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(color: RidoColors.coral50, borderRadius: RidoRadii.cardRadius),
              child: Icon(q.vehicle.kind.icon, color: RidoColors.coral500, fill: 1, size: 28),
            ),
            const SizedBox(width: RidoSpacing.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${q.vehicle.name} fare', style: t.h2),
                  Text(
                    '${short(state.pickup.name)} → ${short(state.drop.name)}',
                    style: t.bodySmall.copyWith(color: RidoColors.navy500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Close',
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Symbols.close_rounded, color: RidoColors.navy900),
            ),
          ],
        ),
        const SizedBox(height: RidoSpacing.l),
        RidoCard(child: FareBreakdown.fromQuote(q)),
        const SizedBox(height: RidoSpacing.l),
        _Note(icon: Symbols.lock_rounded, color: RidoColors.success, text: 'Your fare is locked at booking.'),
        const SizedBox(height: RidoSpacing.m),
        _Note(
          icon: Symbols.trending_up_rounded,
          color: RidoColors.coral500,
          text: 'Surge is capped at 1.5x and goes to your driver.',
        ),
        const SizedBox(height: RidoSpacing.l),
        RidoButton.secondary(label: 'Got it', onPressed: () => Navigator.of(context).maybePop()),
      ],
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.color, required this.text});
  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: color, fill: 1, size: 22),
      const SizedBox(width: RidoSpacing.m),
      Expanded(
        child: Text(text, style: context.type.body.copyWith(color: RidoColors.navy700)),
      ),
    ],
  );
}
