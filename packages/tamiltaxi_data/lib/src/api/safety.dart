import 'package:latlong2/latlong.dart';

import 'api_client.dart';
import 'realtime_client.dart';

Map<String, dynamic> _map(dynamic body) => (body as Map).cast<String, dynamic>();

/// A live-tracking link for a trip (`POST /trips/:id/share`): anyone with [url] can follow the trip until 30 min
/// after it ends; no sign-in, no phone numbers.
class TripShareLink {
  const TripShareLink({required this.url, required this.expiresAt});

  factory TripShareLink.fromJson(Map<String, dynamic> j) => TripShareLink(
        url: '${j['url'] ?? ''}',
        expiresAt: DateTime.tryParse('${j['expiresAt'] ?? ''}')?.toLocal() ?? DateTime.now(),
      );

  final String url;
  final DateTime expiresAt;
}

/// An SOS the API recorded (`POST /trips/:id/sos`): admins are alerted; [shareUrl] is a live link to text to
/// emergency contacts (null once the trip ended more than 30 min ago).
class SosAlert {
  const SosAlert({required this.id, required this.status, this.shareUrl});

  factory SosAlert.fromJson(Map<String, dynamic> j) {
    final sos = _map(j['sos']);
    return SosAlert(id: '${sos['id'] ?? ''}', status: '${sos['status'] ?? 'OPEN'}', shareUrl: j['shareUrl'] as String?);
  }

  final String id;

  /// OPEN, ACKNOWLEDGED, RESOLVED, FALSE_ALARM.
  final String status;
  final String? shareUrl;
}

/// A ride safety check the passenger should answer ("I'm OK" / "Get help"), from the socket (`safety.check`) or a
/// push (`type: safety`). [kind]: STOP (long stop), DEVIATION (route change at night), NIGHT_START (share your
/// trip), SAFE_ARRIVAL ("Did you reach safely?").
class SafetyCheck {
  const SafetyCheck({required this.tripId, required this.kind, this.eventId, this.title = '', this.message = ''});

  factory SafetyCheck.fromJson(Map<String, dynamic> j) => SafetyCheck(
        tripId: '${j['tripId'] ?? ''}',
        kind: '${j['kind'] ?? ''}',
        eventId: j['eventId'] is String ? j['eventId'] as String : null,
        title: '${j['title'] ?? ''}',
        message: '${j['message'] ?? j['body'] ?? ''}',
      );

  final String tripId;
  final String kind;
  final String? eventId;
  final String title;
  final String message;

  /// "Did you reach safely?" (after the ride) rather than "Is everything OK?" (during it).
  bool get isArrival => kind == 'SAFE_ARRIVAL';

  /// Only a reminder to share the trip (no "Get help" question).
  bool get isShareReminder => kind == 'NIGHT_START';
}

/// Trip safety on the Tamil Taxi API: SOS, share links and safety checks.
class LiveSafety {
  LiveSafety(this.api, [this.realtime]);
  final ApiClient api;
  final RealtimeClient? realtime;

  /// Checks pushed on the socket while the app is open (`safety.check` on the passenger's room).
  Stream<SafetyCheck> checks() {
    final rt = realtime;
    if (rt == null) return const Stream.empty();
    rt.connect();
    return rt.on('safety.check').map(SafetyCheck.fromJson);
  }

  /// "I'm OK" ([ok]) or "Get help" to [check]. Help raises an SOS on the server (admins are alerted) and returns it.
  Future<SosAlert?> answer(SafetyCheck check, {required bool ok, LatLng? at}) async {
    final res = _map(await api.post('/trips/${check.tripId}/safety-check', {
      'answer': ok ? 'OK' : 'HELP',
      'eventId': ?check.eventId,
      if (at != null) 'lat': at.latitude,
      if (at != null) 'lng': at.longitude,
    }, true));
    return res['sos'] is Map ? SosAlert.fromJson(_map(res['sos'])) : null;
  }

  /// SOS on [tripId] (passenger or driver) with the phone's position [at]. Safe to repeat: a second SOS within
  /// 2 min returns the first.
  Future<SosAlert> sos(String tripId, {LatLng? at, String? note}) async => SosAlert.fromJson(_map(await api.post(
        '/trips/$tripId/sos',
        {
          if (at != null) 'lat': at.latitude,
          if (at != null) 'lng': at.longitude,
          if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
        },
        true,
      )));

  /// A live-tracking link for [tripId] (passenger).
  Future<TripShareLink> shareLink(String tripId) async => TripShareLink.fromJson(_map(await api.post('/trips/$tripId/share', null, true)));
}
