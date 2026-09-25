/// Google Maps Platform key, passed at build time:
/// `flutter run --dart-define=GOOGLE_MAPS_API_KEY=...`
///
/// Never commit a key. Without one (tests, CI, a plain `flutter run`) every Google code path is
/// skipped and the app uses CARTO tiles + OSRM + the seed places instead.
const googleMapsApiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');

/// Runtime switches for the Google integration.
abstract final class GoogleMapsConfig {
  /// Kill switch (tests set it to false so no Google request is ever made).
  static bool enabled = true;
}

/// True when a key was compiled in and the integration is not switched off.
bool get isGoogleMapsEnabled => GoogleMapsConfig.enabled && googleMapsApiKey.isNotEmpty;
