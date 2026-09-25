import 'dart:ui' show FontFeature, lerpDouble;

import 'package:flutter/material.dart';

import 'rido_colors.dart';

/// 8pt spacing grid. Const so it can be used inside const widgets.
abstract final class RidoSpacing {
  static const double xs = 4;
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// Side padding of every screen.
  static const double gutter = 16;
}

/// Corner radii: 12 cards and inputs, 16 bottom sheets, full-round buttons and chips.
abstract final class RidoRadii {
  static const double card = 12;
  static const double sheet = 16;
  static const double pill = 999;

  static const BorderRadius cardRadius = BorderRadius.all(Radius.circular(card));
  static const BorderRadius sheetTop = BorderRadius.vertical(top: Radius.circular(sheet));
  static const BorderRadius pillRadius = BorderRadius.all(Radius.circular(pill));
}

abstract final class RidoShadows {
  /// y 2, blur 8, navy at 8%.
  static const List<BoxShadow> soft = [BoxShadow(color: RidoColors.shadow, offset: Offset(0, 2), blurRadius: 8)];

  /// Slightly stronger, for floating map controls.
  static const List<BoxShadow> raised = [BoxShadow(color: Color(0x241E293B), offset: Offset(0, 4), blurRadius: 16)];
}

/// Named text styles from the Part 1 type scale. Access with `context.type.h1`.
@immutable
class RidoTextStyles {
  const RidoTextStyles({
    required this.display,
    required this.h1,
    required this.h2,
    required this.body,
    required this.bodyMedium,
    required this.bodySemibold,
    required this.bodySmall,
    required this.bodySmallMedium,
    required this.caption,
    required this.button,
    required this.overline,
    required this.hero,
    required this.heroSmall,
    required this.otp,
  });

  /// 28/36 Poppins Bold.
  final TextStyle display;

  /// 22/30 Poppins SemiBold.
  final TextStyle h1;

  /// 18/26 Poppins SemiBold.
  final TextStyle h2;

  /// 16/24 Inter Regular.
  final TextStyle body;

  /// 16/24 Inter Medium.
  final TextStyle bodyMedium;

  /// 16/24 Inter SemiBold.
  final TextStyle bodySemibold;

  /// 14/20 Inter Regular.
  final TextStyle bodySmall;

  /// 14/20 Inter Medium.
  final TextStyle bodySmallMedium;

  /// 12/16 Inter Regular.
  final TextStyle caption;

  /// 16/24 Inter SemiBold.
  final TextStyle button;

  /// 12/16 Inter SemiBold, letter-spaced, for section labels ("RECENT TRIP").
  final TextStyle overline;

  /// 56/64 Poppins Bold, tabular: big amounts ("₹38" on P-19, D-15, D-19).
  final TextStyle hero;

  /// 40/48 Poppins Bold, tabular: large amounts in cards ("₹1,420", "₹8,940 this week").
  final TextStyle heroSmall;

  /// 28/34 Poppins SemiBold, tabular: OTP digits and big counters.
  final TextStyle otp;

  /// Adds tabular (fixed-width) figures for fares, OTPs and timers.
  static TextStyle tabular(TextStyle s) =>
      s.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

  RidoTextStyles lerp(RidoTextStyles other, double t) => RidoTextStyles(
        display: TextStyle.lerp(display, other.display, t)!,
        h1: TextStyle.lerp(h1, other.h1, t)!,
        h2: TextStyle.lerp(h2, other.h2, t)!,
        body: TextStyle.lerp(body, other.body, t)!,
        bodyMedium: TextStyle.lerp(bodyMedium, other.bodyMedium, t)!,
        bodySemibold: TextStyle.lerp(bodySemibold, other.bodySemibold, t)!,
        bodySmall: TextStyle.lerp(bodySmall, other.bodySmall, t)!,
        bodySmallMedium: TextStyle.lerp(bodySmallMedium, other.bodySmallMedium, t)!,
        caption: TextStyle.lerp(caption, other.caption, t)!,
        button: TextStyle.lerp(button, other.button, t)!,
        overline: TextStyle.lerp(overline, other.overline, t)!,
        hero: TextStyle.lerp(hero, other.hero, t)!,
        heroSmall: TextStyle.lerp(heroSmall, other.heroSmall, t)!,
        otp: TextStyle.lerp(otp, other.otp, t)!,
      );
}

/// Theme extension holding spacing, radii, shadows and the named type scale.
@immutable
class RidoTokens extends ThemeExtension<RidoTokens> {
  const RidoTokens({
    required this.text,
    this.spaceXs = RidoSpacing.xs,
    this.spaceS = RidoSpacing.s,
    this.spaceM = RidoSpacing.m,
    this.spaceL = RidoSpacing.l,
    this.spaceXl = RidoSpacing.xl,
    this.spaceXxl = RidoSpacing.xxl,
    this.radiusCard = RidoRadii.card,
    this.radiusSheet = RidoRadii.sheet,
    this.radiusPill = RidoRadii.pill,
    this.shadow = RidoShadows.soft,
  });

  /// Named type scale. (Not called `type`: that name is ThemeExtension's lookup key.)
  final RidoTextStyles text;
  final double spaceXs;
  final double spaceS;
  final double spaceM;
  final double spaceL;
  final double spaceXl;
  final double spaceXxl;
  final double radiusCard;
  final double radiusSheet;
  final double radiusPill;
  final List<BoxShadow> shadow;

  @override
  RidoTokens copyWith({RidoTextStyles? text, List<BoxShadow>? shadow}) =>
      RidoTokens(text: text ?? this.text, shadow: shadow ?? this.shadow);

  @override
  RidoTokens lerp(ThemeExtension<RidoTokens>? other, double t) {
    if (other is! RidoTokens) return this;
    return RidoTokens(
      text: text.lerp(other.text, t),
      spaceXs: lerpDouble(spaceXs, other.spaceXs, t)!,
      spaceS: lerpDouble(spaceS, other.spaceS, t)!,
      spaceM: lerpDouble(spaceM, other.spaceM, t)!,
      spaceL: lerpDouble(spaceL, other.spaceL, t)!,
      spaceXl: lerpDouble(spaceXl, other.spaceXl, t)!,
      spaceXxl: lerpDouble(spaceXxl, other.spaceXxl, t)!,
      radiusCard: lerpDouble(radiusCard, other.radiusCard, t)!,
      radiusSheet: lerpDouble(radiusSheet, other.radiusSheet, t)!,
      radiusPill: lerpDouble(radiusPill, other.radiusPill, t)!,
      shadow: t < 0.5 ? shadow : other.shadow,
    );
  }
}

extension RidoThemeContext on BuildContext {
  RidoTokens get tokens => Theme.of(this).extension<RidoTokens>()!;

  /// Named type scale: `context.type.h1`, `context.type.caption`…
  RidoTextStyles get type => tokens.text;
}
