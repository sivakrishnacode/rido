/// Rido backend base URL (the `/v1` REST prefix). Override per build:
/// `--dart-define=RIDO_API_URL=https://api.example.com/v1`.
///
/// Default: the staging server on AWS (plain HTTP until a domain + TLS are set up; the Android apps allow
/// cleartext traffic to this host only, see `network_security_config.xml`).
const String kApiBaseUrl = String.fromEnvironment('RIDO_API_URL', defaultValue: 'http://65.0.233.253:3000/v1');

/// true (default) = the apps talk to the backend; false = in-app seed data and the trip simulator
/// (design gallery, widget tests, offline demos): `--dart-define=RIDO_LIVE_API=false`.
const bool kUseLiveApi = bool.fromEnvironment('RIDO_LIVE_API', defaultValue: true);
