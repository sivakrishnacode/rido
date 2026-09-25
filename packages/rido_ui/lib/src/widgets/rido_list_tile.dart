import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/rido_colors.dart';
import '../theme/rido_tokens.dart';

/// Settings-style list tile: leading icon, title, optional subtitle, chevron or trailing widget.
class RidoListTile extends StatelessWidget {
  const RidoListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.onTap,
    this.trailing,
    this.destructive = false,
    this.showChevron = true,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool destructive;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final fg = destructive ? RidoColors.error : RidoColors.navy900;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: destructive ? RidoColors.error : RidoColors.navy700),
                const SizedBox(width: 16),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: t.bodyMedium.copyWith(color: fg)),
                    if (subtitle != null) Text(subtitle!, style: t.bodySmall.copyWith(color: RidoColors.navy500)),
                  ],
                ),
              ),
              if (trailing != null)
                trailing!
              else if (showChevron && !destructive)
                const Icon(Symbols.chevron_right_rounded, color: RidoColors.navy500),
            ],
          ),
        ),
      ),
    );
  }
}

/// A white rounded group of [RidoListTile]s separated by inset dividers.
class RidoListGroup extends StatelessWidget {
  const RidoListGroup({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: RidoColors.surface,
          borderRadius: RidoRadii.cardRadius,
          border: Border.all(color: RidoColors.divider),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const Divider(indent: 56, height: 1),
              children[i],
            ],
          ],
        ),
      );
}
