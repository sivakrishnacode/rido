import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/rido_colors.dart';

/// Every illustration used across both apps.
enum IllustrationKind {
  onboardingFares,
  onboardingDriver,
  onboardingParcels,
  locationPin,
  success,
  parcelDelivered,
  emptyTrips,
  emptyParcel,
  noDrivers,
  driverCancelled,
  offline,
  locationOff,
  outsideArea,
  review,
  kycRejected,
  onHold,
  selfie,
  paymentFailed,
  emptyEarnings,
  waiting,
  happyDriver,
  planActive,
  support,
}

/// Flat "orb" illustration used by state and success screens: a coral-50 outer circle,
/// coral-100 inner circle, a large filled symbol, a navy accent dot and an optional badge.
/// DS-07 rules: flat fills, no gradients, 2–3 palette colours. Onboarding scenes are separate.
class RidoIllustration extends StatelessWidget {
  const RidoIllustration(this.kind, {super.key, this.width = 240, this.height = 200});

  final IllustrationKind kind;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final spec = _spec(kind);
    final d = height < width ? height : width;
    final inner = spec.bg == RidoColors.coral50
        ? RidoColors.coral100
        : spec.bg == RidoColors.inputBg
            ? RidoColors.divider
            : Color.alphaBlend(spec.mainColor.withValues(alpha: 0.18), spec.bg);
    return Semantics(
      image: true,
      label: spec.label,
      child: SizedBox(
        width: width,
        height: height,
        child: Center(
          child: SizedBox(
            width: d,
            height: d,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer and inner orbs.
                Container(width: d, height: d, decoration: BoxDecoration(color: spec.bg, shape: BoxShape.circle)),
                Container(
                  width: d * 0.7,
                  height: d * 0.7,
                  decoration: BoxDecoration(color: inner, shape: BoxShape.circle),
                ),
                // Accent dots on the outer ring.
                Positioned(top: d * 0.12, right: d * 0.1, child: _dot(d * 0.08, RidoColors.navy900)),
                Positioned(bottom: d * 0.16, left: d * 0.1, child: _dot(d * 0.05, spec.dotColor)),
                if (spec.second != null)
                  Positioned(
                    left: d * 0.2,
                    bottom: d * 0.26,
                    child: Icon(spec.second, size: d * 0.18, color: spec.secondColor, fill: 1),
                  ),
                Icon(spec.main, size: d * 0.36, color: spec.mainColor, fill: 1),
                if (spec.badge != null)
                  Positioned(
                    right: d * 0.2,
                    bottom: d * 0.22,
                    child: Container(
                      width: d * 0.22,
                      height: d * 0.22,
                      decoration: BoxDecoration(
                        color: spec.badgeBg,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                      child: Icon(spec.badge, size: d * 0.12, color: Colors.white, fill: 1, weight: 700),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dot(double size, Color c) =>
      Container(width: size, height: size, decoration: BoxDecoration(color: c, shape: BoxShape.circle));

  static _Spec _spec(IllustrationKind k) => switch (k) {
        IllustrationKind.onboardingFares => const _Spec('A bike taxi in a city street', Symbols.two_wheeler_rounded,
            second: Symbols.location_city_rounded, secondColor: RidoColors.navy700, badge: Symbols.currency_rupee_rounded),
        IllustrationKind.onboardingDriver => const _Spec('A smiling driver', Symbols.sentiment_very_satisfied_rounded,
            mainColor: RidoColors.navy900, second: Symbols.electric_rickshaw_rounded, badge: Symbols.percent_rounded),
        IllustrationKind.onboardingParcels => const _Spec('A bike and a small delivery truck', Symbols.local_shipping_rounded,
            second: Symbols.two_wheeler_rounded, secondColor: RidoColors.navy900, badge: Symbols.package_2_rounded),
        IllustrationKind.locationPin => const _Spec('A map pin', Symbols.location_on_rounded,
            second: Symbols.map_rounded, secondColor: RidoColors.navy700),
        IllustrationKind.success => const _Spec('Ride complete', Symbols.electric_rickshaw_rounded,
            mainColor: RidoColors.navy900, badge: Symbols.check_rounded, badgeBg: RidoColors.success,
            second: Symbols.savings_rounded),
        IllustrationKind.parcelDelivered => const _Spec('Parcel delivered', Symbols.deployed_code_rounded,
            badge: Symbols.check_rounded, badgeBg: RidoColors.success, second: Symbols.door_front_rounded,
            secondColor: RidoColors.navy700),
        IllustrationKind.emptyTrips => const _Spec('No trips yet', Symbols.route_rounded,
            bg: RidoColors.inputBg, mainColor: RidoColors.navy500, accent: RidoColors.coral500),
        IllustrationKind.emptyParcel => const _Spec('An empty parcel box with a heart sticker', Symbols.package_2_rounded,
            bg: RidoColors.inputBg, mainColor: RidoColors.navy500, badge: Symbols.favorite_rounded),
        IllustrationKind.noDrivers => const _Spec('No drivers nearby', Symbols.radar_rounded,
            bg: RidoColors.inputBg, mainColor: RidoColors.navy500, second: Symbols.two_wheeler_rounded),
        IllustrationKind.driverCancelled => const _Spec('Finding another driver', Symbols.person_search_rounded,
            second: Symbols.two_wheeler_rounded, secondColor: RidoColors.navy700),
        IllustrationKind.offline => const _Spec("You're offline", Symbols.wifi_off_rounded,
            bg: RidoColors.inputBg, mainColor: RidoColors.navy700),
        IllustrationKind.locationOff => const _Spec('Location is off', Symbols.location_off_rounded,
            second: Symbols.map_rounded, secondColor: RidoColors.navy500),
        IllustrationKind.outsideArea => const _Spec('Outside the service area', Symbols.wrong_location_rounded,
            second: Symbols.explore_rounded, secondColor: RidoColors.navy700),
        IllustrationKind.review => const _Spec('Documents under review', Symbols.description_rounded,
            mainColor: RidoColors.navy700, badge: Symbols.schedule_rounded, badgeBg: RidoColors.warning),
        IllustrationKind.kycRejected => const _Spec('Document rejected', Symbols.badge_rounded,
            mainColor: RidoColors.navy700, badge: Symbols.close_rounded, badgeBg: RidoColors.error),
        IllustrationKind.onHold => const _Spec('Account on hold', Symbols.front_hand_rounded,
            bg: RidoColors.warningTint, mainColor: RidoColors.warning, badge: Symbols.pause_rounded, badgeBg: RidoColors.navy900),
        IllustrationKind.selfie => const _Spec('Selfie check', Symbols.face_rounded,
            mainColor: RidoColors.navy900, badge: Symbols.photo_camera_rounded),
        IllustrationKind.paymentFailed => const _Spec('Payment failed', Symbols.credit_card_off_rounded,
            bg: RidoColors.warningTint, mainColor: RidoColors.warning, badge: Symbols.priority_high_rounded, badgeBg: RidoColors.error),
        IllustrationKind.emptyEarnings => const _Spec('No earnings yet', Symbols.account_balance_wallet_rounded,
            bg: RidoColors.inputBg, mainColor: RidoColors.navy500, badge: Symbols.currency_rupee_rounded),
        IllustrationKind.waiting => const _Spec('Waiting for rides', Symbols.hourglass_top_rounded,
            second: Symbols.two_wheeler_rounded, secondColor: RidoColors.navy900),
        IllustrationKind.happyDriver => const _Spec('A happy driver', Symbols.sentiment_very_satisfied_rounded,
            mainColor: RidoColors.navy900, second: Symbols.two_wheeler_rounded, badge: Symbols.currency_rupee_rounded),
        IllustrationKind.planActive => const _Spec('Plan activated', Symbols.workspace_premium_rounded,
            badge: Symbols.check_rounded, badgeBg: RidoColors.success),
        IllustrationKind.support => const _Spec('Help and support', Symbols.support_agent_rounded,
            mainColor: RidoColors.navy900, badge: Symbols.chat_rounded),
      };
}

class _Spec {
  const _Spec(
    this.label,
    this.main, {
    this.mainColor = RidoColors.coral500,
    this.second,
    this.secondColor = RidoColors.coral600,
    this.badge,
    this.badgeBg = RidoColors.coral600,
    this.bg = RidoColors.coral50,
    this.accent = RidoColors.coral100,
  });

  final String label;
  final IconData main;
  final Color mainColor;
  final IconData? second;
  final Color secondColor;
  final IconData? badge;
  final Color badgeBg;
  final Color bg;
  final Color accent;

  /// Small dot at the bottom-left: green for success pieces, coral otherwise.
  Color get dotColor => badgeBg == RidoColors.success ? RidoColors.success : RidoColors.coral500;
}
