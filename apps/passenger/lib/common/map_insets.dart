import 'package:flutter/widgets.dart';
import 'package:rido_ui/rido_ui.dart';

/// Map insets for a screen whose bottom sheet covers the lower [sheet] pixels of the map.
///
/// Google engine: `mapPadding` keeps the Google logo above the sheet (required by the Maps terms). Google then
/// centres the camera in the padded area, so half the sheet moves from the bottom of [fit] to its top; the
/// padded box the route is fitted into stays the same. flutter_map (tests, no key): no padding, [fit] as is.
({EdgeInsets map, EdgeInsets fit}) sheetMapInsets(EdgeInsets fit, double sheet) {
  if (!RidoMap.usesGoogle || sheet <= 0) return (map: EdgeInsets.zero, fit: fit);
  final half = sheet / 2;
  return (
    map: EdgeInsets.only(bottom: sheet),
    fit: fit.copyWith(top: fit.top + half, bottom: (fit.bottom - half).clamp(0, double.infinity).toDouble()),
  );
}

/// `mapPadding` alone, for maps that set a centre instead of fitting points.
EdgeInsets sheetMapPadding(double sheet) => RidoMap.usesGoogle ? EdgeInsets.only(bottom: sheet) : EdgeInsets.zero;
