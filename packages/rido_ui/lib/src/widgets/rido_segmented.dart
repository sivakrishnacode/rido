import 'package:flutter/material.dart';

import '../theme/rido_colors.dart';
import '../theme/rido_tokens.dart';

/// Segmented control used for "Who pays the driver?" and the earnings tabs.
class RidoSegmented<T> extends StatelessWidget {
  const RidoSegmented({
    super.key,
    required this.options,
    required this.labelOf,
    required this.selected,
    required this.onChanged,
    this.dark = false,
  });

  final List<T> options;
  final String Function(T) labelOf;
  final T selected;
  final ValueChanged<T> onChanged;

  /// Navy-700 track with a white thumb (driver app header).
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: dark ? RidoColors.navy700 : RidoColors.inputBg,
        borderRadius: RidoRadii.pillRadius,
      ),
      child: Row(
        children: [
          for (final o in options)
            Expanded(
              child: Semantics(
                selected: o == selected,
                button: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(o),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: o == selected ? RidoColors.surface : Colors.transparent,
                      borderRadius: RidoRadii.pillRadius,
                      boxShadow: o == selected && !dark ? RidoShadows.soft : null,
                    ),
                    child: Text(
                      labelOf(o),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.bodyMedium.copyWith(
                        color: o == selected ? RidoColors.navy900 : (dark ? Colors.white70 : RidoColors.navy500),
                        fontWeight: o == selected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
