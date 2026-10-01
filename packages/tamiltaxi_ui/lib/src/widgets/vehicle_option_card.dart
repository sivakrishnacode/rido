import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../format.dart';
import '../theme/tt_colors.dart';
import '../theme/tt_tokens.dart';

/// Badge style on a vehicle card: "Lowest" / "Best value" = coral, "Comfort" / "Fastest" = navy.
enum VehicleBadgeTone { coral, navy }

/// Vehicle option card: the vehicle's picture ([art]) or a symbol tile, name + capacity + badges,
/// "3 min away · Drop 9:24 PM", fare.
/// Selected = coral-50 fill + coral-100 border. Disabled shows [disabledReason] in grey. [fastest] adds a
/// "Fastest" chip (earliest drop of the list).
class VehicleOptionCard extends StatelessWidget {
  const VehicleOptionCard({
    super.key,
    required this.icon,
    required this.name,
    required this.subtitle,
    required this.fare,
    this.selected = false,
    this.badge,
    this.badgeTone = VehicleBadgeTone.coral,
    this.disabledReason,
    this.onTap,
    this.capacity,
    this.fastest = false,
    this.art,
  });

  final IconData icon;

  /// The vehicle's picture (e.g. [VehicleArt]); when set it replaces the coral symbol tile, like Rapido's list.
  final Widget? art;
  final String name;

  /// "3 min away · Drop 9:24 PM" (or "2 min away · 1 seat" when [capacity] is not given).
  final String subtitle;

  /// "1 seat", "4 seats": shown next to the name as "👤 1" (the full text for screen readers).
  final String? capacity;

  /// Earliest drop of the list: a "Fastest" chip with a bolt.
  final bool fastest;
  final int fare;
  final bool selected;
  final String? badge;
  final VehicleBadgeTone badgeTone;

  /// When set, the card is greyed out and not tappable.
  final String? disabledReason;
  final VoidCallback? onTap;

  bool get _disabled => disabledReason != null;

  /// "3" from "3 seats" / "1 seat"; null for other capacities.
  String? get _seats => RegExp(r'^(\d+) seats?$').firstMatch(capacity ?? '')?.group(1);

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final fg = _disabled ? TtColors.navy500 : TtColors.navy900;
    return Semantics(
      selected: selected,
      enabled: !_disabled,
      button: true,
      label: [
        name,
        ?capacity,
        if (fastest && !_disabled) 'Fastest',
        _disabled ? disabledReason! : subtitle,
        formatInr(fare),
      ].join(', '),
      excludeSemantics: true,
      child: Opacity(
        opacity: _disabled ? 0.6 : 1,
        child: Material(
          color: selected ? TtColors.coral50 : (_disabled ? TtColors.background : TtColors.surface),
          shape: RoundedRectangleBorder(
            borderRadius: TtRadii.cardRadius,
            side: BorderSide(color: selected ? TtColors.coral100 : TtColors.divider, width: selected ? 1.5 : 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: _disabled ? null : onTap,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  if (art != null)
                    SizedBox(width: 72, height: 52, child: Center(child: art))
                  else
                    Container(
                      width: 56,
                      height: 52,
                      decoration: BoxDecoration(
                        color: selected ? TtColors.surface : (_disabled ? TtColors.inputBg : TtColors.coral50),
                        borderRadius: TtRadii.cardRadius,
                      ),
                      child: Icon(icon, size: 32, color: _disabled ? TtColors.navy500 : TtColors.coral500, fill: 1),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(name,
                                  style: t.bodySemibold.copyWith(fontSize: 17, color: fg),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ),
                            // Seats as "👤 3" (like Rapido) so a long name ("Auto Priority") keeps its room; other
                            // capacities ("Up to 500 kg") shrink with ellipsis. Screen readers get the full label.
                            if (capacity != null) ...[
                              const SizedBox(width: 6),
                              Icon(Symbols.person_rounded, size: 16, color: TtColors.navy500, fill: 1),
                              if (_seats != null)
                                Text(_seats!, style: t.caption.copyWith(color: TtColors.navy500), maxLines: 1)
                              else
                                Flexible(
                                  child: Text(capacity!,
                                      style: t.caption.copyWith(color: TtColors.navy500),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                ),
                            ],
                            if (fastest && !_disabled) ...[
                              const SizedBox(width: 8),
                              const _Badge(label: 'Fastest', tone: VehicleBadgeTone.navy, icon: Symbols.bolt_rounded),
                            ] else if (badge != null && !_disabled) ...[
                              const SizedBox(width: 8),
                              _Badge(label: badge!, tone: badgeTone),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _disabled ? disabledReason! : subtitle,
                          style: t.bodySmall.copyWith(color: _disabled ? TtColors.navy500 : TtColors.navy700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(formatInr(fare), style: TtTextStyles.tabular(t.h2.copyWith(color: fg))),
                  const SizedBox(width: 6),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.tone, this.icon});
  final String label;
  final VehicleBadgeTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: tone == VehicleBadgeTone.coral ? TtColors.coral600 : TtColors.navy900,
          borderRadius: TtRadii.pillRadius,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: Colors.white, fill: 1),
              const SizedBox(width: 2),
            ],
            Text(label, style: context.type.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
          ],
        ),
      );
}
