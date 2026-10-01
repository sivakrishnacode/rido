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
///
/// [laneShift] moves the lane dashes along the x's over-road, in dash periods (the intro animation): 0 or any whole
/// number is the logo exactly as drawn. The dashes stay inside the road, so the x never comes apart from "Taxi".
class TtAppName extends StatelessWidget {
  const TtAppName({super.key, this.width = 122, this.color = Colors.white, this.laneShift = 0});

  final double width;
  final Color color;
  final double laneShift;

  @override
  Widget build(BuildContext context) {
    final shift = laneShift - laneShift.floorToDouble();
    return Semantics(
      label: 'Tamil Taxi',
      excludeSemantics: true,
      child: CustomPaint(
        size: Size(width, width * TtLogoPaths.appNameAspect),
        painter: shift < 1e-6 || shift > 1 - 1e-6 ? _AppNamePainter(width, color) : _AppNameLanesPainter(width, color, shift),
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

/// The x of [TtLogoPaths.appName] (width 1.0): its over-road band and the two lane dashes cut out of it, copied from
/// the generated outline (contours 5, 16 and 17; `tt_app_name_test.dart` checks they still match).
abstract final class AppNameRoad {
  static const band = [Offset(0.56061, 0.60286), Offset(0.63960, 0.60286), Offset(0.81035, 0.85051), Offset(0.73137, 0.85051)];
  static const dash = [Offset(0.62576, 0.62859), Offset(0.61505, 0.63603), Offset(0.66325, 0.70593), Offset(0.67396, 0.69865)];

  /// From one dash to the next (the second dash is the first moved by this much).
  static const period = Offset(0.08196, 0.11899);

  static Path polygon(List<Offset> pts, [Offset by = Offset.zero]) =>
      Path()..addPolygon([for (final p in pts) p + by], true);

  /// Path operations run at this scale: at width 1.0 Skia's tolerances drop some cuts.
  static const double _opsScale = 1000;

  static Path _big(List<Offset> pts, [Offset by = Offset.zero]) =>
      Path()..addPolygon([for (final p in pts) (p + by) * _opsScale], true);

  static Path? _solid;

  /// The name (at [_opsScale]) with the dashes' holes filled in.
  static Path get _solidBig => _solid ??= Path.combine(
        PathOperation.union,
        TtLogoPaths.appName().transform(Matrix4.diagonal3Values(_opsScale, _opsScale, 1).storage),
        _big(dash)..addPath(_big(dash, period), Offset.zero),
      );

  /// The name (width 1.0) with its lane dashes moved [shift] periods along the road (0 or a whole number: as drawn).
  /// The moved dashes are cut out of the band only, so they never reach past the x.
  static Path nameAt(double shift) {
    final moved = Path();
    for (var k = -3; k <= 2; k++) {
      moved.addPath(_big(dash, period * (k + shift)), Offset.zero);
    }
    final cut = Path.combine(PathOperation.intersect, _big(band), moved);
    const back = 1 / _opsScale;
    return Path.combine(PathOperation.difference, _solidBig, cut)
        .transform(Matrix4.diagonal3Values(back, back, 1).storage);
  }
}

/// [TtAppName] with its lane dashes moved (path operations, so no seams and it works on any background).
class _AppNameLanesPainter extends CustomPainter {
  _AppNameLanesPainter(this.width, this.color, this.shift);

  final double width;
  final Color color;
  final double shift;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      AppNameRoad.nameAt(shift).transform(Matrix4.diagonal3Values(width, width, 1).storage),
      Paint()..color = color..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(_AppNameLanesPainter old) => old.width != width || old.color != color || old.shift != shift;
}
