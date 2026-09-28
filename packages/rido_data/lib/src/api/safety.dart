import 'package:latlong2/latlong.dart';

import 'api_client.dart';

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

/// Trip safety on the Rido API: SOS and share links.
class LiveSafety {
  LiveSafety(this.api);
  final ApiClient api;

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
