import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// A non-200 answer from a Google Maps Platform web service.
class GoogleApiException implements Exception {
  const GoogleApiException(this.statusCode, this.body);
  final int statusCode;
  final String body;

  /// Key missing / invalid / API not enabled / billing off: retrying will not help.
  bool get isConfigError => statusCode == 400 || statusCode == 401 || statusCode == 403;

  @override
  String toString() => 'GoogleApiException($statusCode)';
}

/// One JSON request over dart:io (no extra HTTP package). Throws on timeout, socket errors and
/// non-200 responses; returns the decoded JSON body.
Future<Object?> googleJsonRequest(
  String method,
  Uri uri, {
  Map<String, String> headers = const {},
  Object? body,
  Duration timeout = const Duration(seconds: 6),
}) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
  try {
    final req = await client.openUrl(method, uri).timeout(timeout);
    headers.forEach(req.headers.set);
    if (body != null) {
      req.headers.contentType = ContentType.json;
      req.add(utf8.encode(jsonEncode(body)));
    }
    final res = await req.close().timeout(timeout);
    final text = await res.transform(utf8.decoder).join().timeout(timeout);
    if (res.statusCode != 200) throw GoogleApiException(res.statusCode, text);
    return jsonDecode(text);
  } finally {
    client.close(force: true);
  }
}
