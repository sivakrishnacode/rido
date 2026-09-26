import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../repositories/repositories.dart';

/// The API answered with an error. [message] is safe to show (the API writes user-facing messages).
class ApiException implements Exception {
  const ApiException(this.status, this.message);
  final int status;
  final String message;

  @override
  String toString() => message;
}

/// Signed-in state kept on the device: the access token and (driver app) the driver id.
class ApiSession {
  ApiSession(this._prefs);
  final SharedPreferences _prefs;

  static const _tokenKey = 'rido.accessToken';
  static const _driverKey = 'rido.driverId';
  static const _onboardingKey = 'rido.seenOnboarding';

  static Future<ApiSession> load() async => ApiSession(await SharedPreferences.getInstance());

  String? get token => _prefs.getString(_tokenKey);
  String? get driverId => _prefs.getString(_driverKey);
  bool get isLoggedIn => (token ?? '').isNotEmpty;
  bool get hasSeenOnboarding => _prefs.getBool(_onboardingKey) ?? false;

  Future<void> save({required String token, String? driverId}) async {
    await _prefs.setString(_tokenKey, token);
    if (driverId != null) {
      await _prefs.setString(_driverKey, driverId);
    } else {
      await _prefs.remove(_driverKey);
    }
  }

  Future<void> markOnboardingSeen() => _prefs.setBool(_onboardingKey, true);

  Future<void> clear() async {
    await _prefs.remove(_tokenKey);
    await _prefs.remove(_driverKey);
  }
}

/// JSON over HTTP to the Rido API with the session's Bearer token.
///
/// Network failures become [OfflineException] (screens already show the offline state for it); API errors become
/// [ApiException] with the API's message. A 401 clears the session and fires [onUnauthorized].
class ApiClient {
  ApiClient({required this.baseUrl, required this.session, http.Client? client}) : _http = client ?? http.Client();

  final String baseUrl;
  final ApiSession session;
  final http.Client _http;
  final _unauthorized = StreamController<void>.broadcast();

  static const _timeout = Duration(seconds: 20);

  /// Fires when the token is rejected (expired, or the account was blocked and signed out).
  Stream<void> get onUnauthorized => _unauthorized.stream;

  /// Origin of the API (for Socket.IO), e.g. `http://65.0.233.253:3000`.
  String get origin {
    final u = Uri.parse(baseUrl);
    return '${u.scheme}://${u.host}${u.hasPort ? ':${u.port}' : ''}';
  }

  Future<dynamic> get(String path, {Map<String, Object?>? query}) => _send('GET', path, query: query);
  Future<dynamic> post(String path, [Object? body]) => _send('POST', path, body: body);
  Future<dynamic> patch(String path, Object? body) => _send('PATCH', path, body: body);
  Future<dynamic> delete(String path) => _send('DELETE', path);

  /// multipart/form-data upload with one file field.
  Future<dynamic> upload(String path, {required String field, required List<int> bytes, required String filename}) async {
    final req = http.MultipartRequest('POST', _uri(path))
      ..headers.addAll(_headers(json: false))
      ..files.add(http.MultipartFile.fromBytes(field, bytes, filename: filename, contentType: _mediaType(filename)));
    return _guard(() async => http.Response.fromStream(await _http.send(req).timeout(const Duration(seconds: 60))));
  }

  Uri _uri(String path, [Map<String, Object?>? query]) {
    final q = {for (final e in (query ?? const {}).entries) if (e.value != null) e.key: '${e.value}'};
    return Uri.parse('$baseUrl$path').replace(queryParameters: q.isEmpty ? null : q);
  }

  Map<String, String> _headers({bool json = true}) => {
        if (json) 'content-type': 'application/json',
        'accept': 'application/json',
        if (session.isLoggedIn) 'authorization': 'Bearer ${session.token}',
      };

  Future<dynamic> _send(String method, String path, {Map<String, Object?>? query, Object? body}) {
    return _guard(() {
      final req = http.Request(method, _uri(path, query))..headers.addAll(_headers(json: body != null));
      if (body != null) req.body = jsonEncode(body);
      return _http.send(req).timeout(_timeout).then(http.Response.fromStream);
    });
  }

  Future<dynamic> _guard(Future<http.Response> Function() run) async {
    final http.Response res;
    try {
      res = await run();
    } on SocketException {
      throw const OfflineException();
    } on TimeoutException {
      throw const OfflineException();
    } on http.ClientException {
      throw const OfflineException();
    } on HandshakeException {
      throw const OfflineException();
    }
    final body = res.body.isEmpty ? null : _decode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    if (res.statusCode == 401 && session.isLoggedIn) {
      await session.clear();
      _unauthorized.add(null);
    }
    throw ApiException(res.statusCode, _message(body) ?? 'Something went wrong (${res.statusCode})');
  }

  static dynamic _decode(String text) {
    try {
      return jsonDecode(text);
    } on FormatException {
      return text;
    }
  }

  static String? _message(dynamic body) {
    if (body is! Map) return null;
    final m = body['message'];
    if (m is String) return m;
    if (m is List && m.isNotEmpty) return '${m.first}';
    return null;
  }

  static http.MediaType? _mediaType(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    return switch (ext) {
      'jpg' || 'jpeg' => http.MediaType('image', 'jpeg'),
      'png' => http.MediaType('image', 'png'),
      'webp' => http.MediaType('image', 'webp'),
      'pdf' => http.MediaType('application', 'pdf'),
      _ => null,
    };
  }
}
