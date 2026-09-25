import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/rido_colors.dart';
import '../theme/rido_tokens.dart';

/// A single Rido chip. Choice chips fill coral-600 when [solid] and selected;
/// filter chips use a coral-50 fill with a check.
class RidoChip extends StatelessWidget {
  const RidoChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.solid = false,
    this.showCheck = false,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;

  /// Solid coral fill when selected (payment choice). Otherwise coral-50 tint.
  final bool solid;
  final bool showCheck;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final bg = selected ? (solid ? RidoColors.coral600 : RidoColors.coral50) : RidoColors.surface;
    final fg = selected ? (solid ? Colors.white : RidoColors.coral600) : RidoColors.navy700;
    final border = selected ? (solid ? RidoColors.coral600 : RidoColors.coral100) : RidoColors.divider;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: bg,
        shape: StadiumBorder(side: BorderSide(color: border)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showCheck && selected) ...[
                    Icon(Symbols.check_rounded, size: 18, color: fg),
                    const SizedBox(width: 4),
                  ] else if (icon != null) ...[
                    Icon(icon, size: 18, color: fg),
                    const SizedBox(width: 6),
                  ],
                  Flexible(
                    child: Text(label,
                        style: t.bodySmallMedium.copyWith(color: fg, fontWeight: selected ? FontWeight.w600 : null),
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A wrap of chips where exactly one (or, with [multi], several) can be selected.
class ChoiceChips<T> extends StatelessWidget {
  const ChoiceChips({
    super.key,
    required this.options,
    required this.labelOf,
    required this.selected,
    required this.onChanged,
    this.iconOf,
    this.solid = false,
    this.showCheck = false,
    this.scrollable = false,
  });

  final List<T> options;
  final String Function(T) labelOf;
  final IconData? Function(T)? iconOf;
  final Set<T> selected;

  /// Called with the tapped option.
  final ValueChanged<T> onChanged;
  final bool solid;
  final bool showCheck;

  /// One horizontally scrolling row instead of a wrap.
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final chips = [
      for (final o in options)
        RidoChip(
          label: labelOf(o),
          icon: iconOf?.call(o),
          selected: selected.contains(o),
          solid: solid,
          showCheck: showCheck,
          onTap: () => onChanged(o),
        ),
    ];
    if (scrollable) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [for (final c in chips) Padding(padding: const EdgeInsets.only(right: 8), child: c)]),
      );
    }
    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }
}
