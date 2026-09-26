import 'package:flutter/widgets.dart';
import 'package:rido_ui/rido_ui.dart';

/// Map insets for a screen whose bottom sheet covers the lower [sheet] pixels of the map.
///
/// Google engine: `mapPadding` keeps the Google logo above the sheet (required by the Maps terms), and RidoMap
/// fits points inside the padded area, so the sheet part of [fit]'s bottom is dropped (keeping a small margin).
/// flutter_map (tests, no key): no padding, [fit] as is.
({EdgeInsets map, EdgeInsets fit}) sheetMapInsets(EdgeInsets fit, double sheet) {
  if (!RidoMap.usesGoogle || sheet <= 0) return (map: EdgeInsets.zero, fit: fit);
  return (
    map: EdgeInsets.only(bottom: sheet),
    fit: fit.copyWith(bottom: (fit.bottom - sheet).clamp(24, double.infinity).toDouble()),
  );
}

/// `mapPadding` alone, for maps that set a centre instead of fitting points.
EdgeInsets sheetMapPadding(double sheet) => RidoMap.usesGoogle ? EdgeInsets.only(bottom: sheet) : EdgeInsets.zero;
