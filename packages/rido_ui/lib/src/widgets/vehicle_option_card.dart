import 'package:flutter/material.dart';

import '../format.dart';
import '../theme/rido_colors.dart';
import '../theme/rido_tokens.dart';

/// Badge style on a vehicle card: "Lowest" / "Best value" = coral, "Comfort" / "Fastest" = navy.
enum VehicleBadgeTone { coral, navy }

/// Vehicle option card: illustration tile, name + badge, "2 min away · 1 seat", fare.
/// Selected = coral-50 fill + coral-100 border. Disabled shows [disabledReason] in grey.
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
  });

  final IconData icon;
  final String name;

  /// "2 min away · 1 seat"
  final String subtitle;
  final int fare;
  final bool selected;
  final String? badge;
  final VehicleBadgeTone badgeTone;

  /// When set, the card is greyed out and not tappable.
  final String? disabledReason;
  final VoidCallback? onTap;

  bool get _disabled => disabledReason != null;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final fg = _disabled ? RidoColors.navy500 : RidoColors.navy900;
    return Semantics(
      selected: selected,
      enabled: !_disabled,
      button: true,
      label: '$name, $subtitle, ${formatInr(fare)}${_disabled ? ', $disabledReason' : ''}',
      excludeSemantics: true,
      child: Opacity(
        opacity: _disabled ? 0.6 : 1,
        child: Material(
          color: selected ? RidoColors.coral50 : (_disabled ? RidoColors.background : RidoColors.surface),
          shape: RoundedRectangleBorder(
            borderRadius: RidoRadii.cardRadius,
            side: BorderSide(color: selected ? RidoColors.coral100 : RidoColors.divider, width: selected ? 1.5 : 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: _disabled ? null : onTap,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 52,
                    decoration: BoxDecoration(
                      color: selected ? RidoColors.surface : (_disabled ? RidoColors.inputBg : RidoColors.coral50),
                      borderRadius: RidoRadii.cardRadius,
                    ),
                    child: Icon(icon, size: 32, color: _disabled ? RidoColors.navy500 : RidoColors.coral500, fill: 1),
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
                            if (badge != null && !_disabled) ...[
                              const SizedBox(width: 8),
                              _Badge(label: badge!, tone: badgeTone),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _disabled ? disabledReason! : subtitle,
                          style: t.bodySmall.copyWith(color: _disabled ? RidoColors.navy500 : RidoColors.navy700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(formatInr(fare), style: RidoTextStyles.tabular(t.h2.copyWith(color: fg))),
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
  const _Badge({required this.label, required this.tone});
  final String label;
  final VehicleBadgeTone tone;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: tone == VehicleBadgeTone.coral ? RidoColors.coral600 : RidoColors.navy900,
          borderRadius: RidoRadii.pillRadius,
        ),
        child: Text(label, style: context.type.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
      );
}
