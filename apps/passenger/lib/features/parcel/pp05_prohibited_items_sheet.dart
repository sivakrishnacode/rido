import 'package:flutter/material.dart';
import 'package:rido_ui/rido_ui.dart';

/// PP-05 Prohibited items: what drivers cannot carry. Content of a bottom sheet.
class PP05ProhibitedItemsSheet extends StatelessWidget {
  const PP05ProhibitedItemsSheet({super.key, this.showcase = false});

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  static const _items = [
    (Symbols.diamond_rounded, 'Cash and jewellery'),
    (Symbols.liquor_rounded, 'Alcohol'),
    (Symbols.medication_rounded, 'Drugs and illegal items'),
    (Symbols.swords_rounded, 'Weapons'),
    (Symbols.local_fire_department_rounded, 'Hazardous or flammable goods'),
    (Symbols.pets_rounded, 'Live animals'),
  ];

  /// Opens the sheet over the current screen.
  static Future<void> show(BuildContext context) =>
      showRidoSheet<void>(context, builder: (_) => const PP05ProhibitedItemsSheet());

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Items we can’t carry', style: t.h1),
        const SizedBox(height: 4),
        Text('Drivers can refuse a parcel that contains any of these.', style: t.bodySmall.copyWith(color: RidoColors.navy700)),
        const SizedBox(height: 12),
        for (final (icon, label) in _items) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(color: RidoColors.errorTint, shape: BoxShape.circle),
                  child: Icon(icon, size: 20, color: RidoColors.error),
                ),
                const SizedBox(width: 16),
                Expanded(child: Text(label, style: t.body)),
              ],
            ),
          ),
          const Divider(),
        ],
        const SizedBox(height: 20),
        RidoButton(label: 'Got it', onPressed: () => Navigator.of(context).maybePop()),
      ],
    );
  }
}
