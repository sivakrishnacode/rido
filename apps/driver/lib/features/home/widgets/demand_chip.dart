import 'package:flutter/material.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

/// A res-7 hex is about 1.2 km across: closer than this to its centre counts as being in it.
const double kInsideHotspotKm = 1.2;

/// Home's "HIGH DEMAND · Gandhipuram · 2.4 km" row with a directions button: the nearest busy area, from the live
/// demand map (like Namma Yatri's home card). [onDirections] opens Google Maps to its centre.
class NearestDemandChip extends StatelessWidget {
  const NearestDemandChip({super.key, required this.hotspot, required this.km, required this.onDirections});

  final Hotspot hotspot;
  final double km;
  final VoidCallback onDirections;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final high = hotspot.level == HotspotLevel.high;
    final inside = km < kInsideHotspotKm;
    final tag = [
      high ? 'HIGH DEMAND' : 'BUSY AREA',
      if (hotspot.isSurging) '${hotspot.multiplier.toStringAsFixed(1)}x',
    ].join(' · ');
    final place = hotspot.name ?? (high ? 'Busy area nearby' : 'Area nearby');
    return Semantics(
      container: true,
      label: '$tag, $place, ${inside ? "you're in it" : formatKm(km)}',
      child: Row(children: [
        const Icon(Symbols.location_on_rounded, color: RidoColors.navy900, size: 26),
        const SizedBox(width: RidoSpacing.m),
        Expanded(
          child: ExcludeSemantics(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Symbols.trending_up_rounded, size: 16, color: high ? RidoColors.coral600 : RidoColors.warningText),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    tag,
                    style: t.overline.copyWith(color: high ? RidoColors.coral600 : RidoColors.warningText),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ]),
              Text(place, style: t.bodySemibold, maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
        ),
        const SizedBox(width: RidoSpacing.m),
        if (inside)
          Text("You're here", style: t.caption.copyWith(color: RidoColors.successText))
        else
          Material(
            color: RidoColors.inputBg,
            borderRadius: RidoRadii.cardRadius,
            child: InkWell(
              borderRadius: RidoRadii.cardRadius,
              onTap: onDirections,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Symbols.turn_right_rounded, color: RidoColors.navy900, size: 22),
                  Text(formatKm(km), style: t.caption.copyWith(color: RidoColors.navy900)),
                ]),
              ),
            ),
          ),
      ]),
    );
  }
}
