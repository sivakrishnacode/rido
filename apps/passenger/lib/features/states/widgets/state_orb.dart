import 'package:flutter/material.dart';
import 'package:rido_ui/rido_ui.dart';

/// Flat "orb" illustration used by the ride state and success screens (P-19, S-01, S-02, S-06):
/// a coral-50 outer circle, an optional coral-100 inner circle, a centre widget, an optional
/// badge at the bottom-right and optional navy / green accent dots.
class StateOrb extends StatelessWidget {
  const StateOrb({
    super.key,
    required this.child,
    this.size = 144,
    this.inner = false,
    this.badge,
    this.badgeColor = RidoColors.navy900,
    this.accentDots = false,
    this.label,
  });

  final Widget child;
  final double size;

  /// Draws the coral-100 inner circle (70% of [size]).
  final bool inner;
  final IconData? badge;
  final Color badgeColor;

  /// Navy dot top-right and green dot bottom-left (P-19).
  final bool accentDots;

  /// Semantic label for the picture.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final d = size;
    return Semantics(
      image: true,
      label: label,
      child: SizedBox(
        width: d,
        height: d,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Container(width: d, height: d, decoration: const BoxDecoration(color: RidoColors.coral50, shape: BoxShape.circle)),
            if (inner)
              Container(
                width: d * 0.72,
                height: d * 0.72,
                decoration: const BoxDecoration(color: RidoColors.coral100, shape: BoxShape.circle),
              ),
            child,
            if (accentDots) ...[
              Positioned(top: d * 0.14, right: d * 0.1, child: _dot(d * 0.1, RidoColors.navy900)),
              Positioned(bottom: d * 0.18, left: d * 0.12, child: _dot(d * 0.068, RidoColors.success)),
            ],
            if (badge != null)
              Positioned(
                right: d * 0.02,
                bottom: d * 0.06,
                child: Container(
                  width: d * 0.3,
                  height: d * 0.3,
                  decoration: BoxDecoration(
                    color: badgeColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: RidoColors.surface, width: 3),
                  ),
                  child: Icon(badge, size: d * 0.15, color: Colors.white, fill: 1, weight: 600),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _dot(double s, Color c) =>
      Container(width: s, height: s, decoration: BoxDecoration(color: c, shape: BoxShape.circle));
}
