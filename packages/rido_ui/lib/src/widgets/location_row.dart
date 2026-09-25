import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/rido_colors.dart';
import '../theme/rido_tokens.dart';

import 'location_markers.dart';

enum LocationRowKind { pickup, drop, recent, saved, landmark, search }

/// One place row: leading icon + title + subtitle, optional trailing text (distance) and chevron.
class LocationRow extends StatelessWidget {
  const LocationRow({
    super.key,
    required this.title,
    this.subtitle,
    this.kind = LocationRowKind.search,
    this.icon,
    this.trailingText,
    this.showChevron = false,
    this.onTap,
    this.dense = false,
  });

  final String title;
  final String? subtitle;
  final LocationRowKind kind;

  /// Overrides the kind's default icon (e.g. flight for the airport).
  final IconData? icon;
  final String? trailingText;
  final bool showChevron;
  final VoidCallback? onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final Widget leading = switch (kind) {
      LocationRowKind.pickup => const SizedBox(width: 40, child: Center(child: PickupDot(size: 12))),
      LocationRowKind.drop => const SizedBox(width: 40, child: Center(child: DropPin())),
      LocationRowKind.recent => _circle(icon ?? Symbols.history_rounded, RidoColors.inputBg, RidoColors.navy700),
      LocationRowKind.saved ||
      LocationRowKind.landmark =>
        _circle(icon ?? Symbols.star_rounded, RidoColors.coral50, RidoColors.coral600),
      LocationRowKind.search => _circle(icon ?? Symbols.location_on_rounded, RidoColors.inputBg, RidoColors.navy700),
    };
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: dense ? 8 : 12),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: t.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: t.bodySmall.copyWith(color: RidoColors.navy500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (trailingText != null) ...[
                const SizedBox(width: 8),
                Text(trailingText!, style: t.caption),
              ],
              if (showChevron) ...[
                const SizedBox(width: 4),
                const Icon(Symbols.chevron_right_rounded, color: RidoColors.navy500),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _circle(IconData icon, Color bg, Color fg) => Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: Icon(icon, color: fg, size: 22),
      );
}
