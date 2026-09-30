import 'package:flutter/material.dart';

import '../theme/tt_colors.dart';
import 'tt_logo_paths.dart';

/// The Tamil Taxi logo: "Tamil / Taxi" in Manrope ExtraBold whose x is a flyover road with lane dashes.
/// Drawn from outline paths (see [TtLogoPaths]), so it never depends on a font being loaded.
///
/// [size] is the font size the letters are set at; the stacked logo is about 1.7 × [size] tall.
/// [roadColor] defaults to coral when the letters are the default navy, and to [color] otherwise
/// (white on coral stays all white).
class TtWordmark extends StatelessWidget {
  const TtWordmark({super.key, this.size = 48, this.color = TtColors.navy900, this.roadColor, this.stacked = true});

  final double size;
  final Color color;
  final Color? roadColor;

  /// Two lines ("Tamil" over "Taxi", the primary logo) or one line for app bars and other short, wide spaces.
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final w = (stacked ? TtLogoPaths.stackedWidth : TtLogoPaths.oneLineWidth) * size;
    final h = (stacked ? TtLogoPaths.stackedHeight : TtLogoPaths.oneLineHeight) * size;
    final road = roadColor ?? (color == TtColors.navy900 ? TtColors.coral500 : color);
    return Semantics(
      label: 'Tamil Taxi',
      excludeSemantics: true,
      child: CustomPaint(size: Size(w, h), painter: _LogoPainter(size, color, road, stacked)),
    );
  }
}

class _LogoPainter extends CustomPainter {
  _LogoPainter(this.scale, this.color, this.road, this.stacked);

  final double scale;
  final Color color;
  final Color road;
  final bool stacked;

  @override
  void paint(Canvas canvas, Size size) {
    final m = Matrix4.diagonal3Values(scale, scale, 1).storage;
    final fg = (stacked ? TtLogoPaths.stackedFg() : TtLogoPaths.oneLineFg()).transform(m);
    final rd = (stacked ? TtLogoPaths.stackedRoad() : TtLogoPaths.oneLineRoad()).transform(m);
    canvas.drawPath(fg, Paint()..color = color..isAntiAlias = true);
    canvas.drawPath(rd, Paint()..color = road..isAntiAlias = true);
  }

  @override
  bool shouldRepaint(_LogoPainter old) =>
      old.scale != scale || old.color != color || old.road != road || old.stacked != stacked;
}

/// The app name as it appears on the launcher icons and the native splash: "தமிழ்" (Anek Tamil) over "Taxi"
/// (Anek Latin, road x, pulli-shaped i dot), one colour. Used where the app continues the native splash, so the
/// first Flutter frame matches it. [width] is the width of the name; the height follows [TtLogoPaths.appNameAspect].
class TtAppName extends StatelessWidget {
  const TtAppName({super.key, this.width = 122, this.color = Colors.white});

  final double width;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Tamil Taxi',
      excludeSemantics: true,
      child: CustomPaint(
        size: Size(width, width * TtLogoPaths.appNameAspect),
        painter: _AppNamePainter(width, color),
      ),
    );
  }
}

class _AppNamePainter extends CustomPainter {
  _AppNamePainter(this.width, this.color);

  final double width;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = TtLogoPaths.appName().transform(Matrix4.diagonal3Values(width, width, 1).storage);
    canvas.drawPath(path, Paint()..color = color..isAntiAlias = true);
  }

  @override
  bool shouldRepaint(_AppNamePainter old) => old.width != width || old.color != color;
}
