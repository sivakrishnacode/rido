import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/tt_colors.dart';
import '../theme/tt_tokens.dart';

/// "#NammaOoru · Made in Coimbatore" footer at the end of the passenger home sheet: a full-width picture in navy
/// line art with coral touches (gopurams, the clock tower, the Nilgiri hills and train, an auto, a bike taxi and a
/// car on the road, a Bharatanatyam dancer, a Pongal pot, a kolam, a farmer ploughing with Kangayam bulls) with the
/// words over its empty top. A 256-colour PNG (transparent around the art).
class HomeFooter extends StatelessWidget {
  const HomeFooter({super.key});

  static const asset = 'packages/tamiltaxi_ui/assets/illustrations/home_footer.png';

  /// Width : height of the picture (1448 × 914 px).
  static const aspectRatio = 1448 / 914;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: 'Namma Ooru. Made in Coimbatore',
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(asset, fit: BoxFit.cover),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '#NammaOoru',
                      maxLines: 1,
                      style: t.display.copyWith(fontSize: 40, height: 1.2, color: TtColors.navy300),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Symbols.location_on_rounded, size: 18, fill: 1, color: TtColors.coral500),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'Made in Coimbatore',
                          style: t.bodySmallMedium.copyWith(color: TtColors.navy700),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
