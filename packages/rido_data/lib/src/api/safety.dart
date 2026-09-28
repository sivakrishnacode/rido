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

/// Trip safety on the Rido API: share links.
class LiveSafety {
  LiveSafety(this.api);
  final ApiClient api;

  /// A live-tracking link for [tripId] (passenger).
  Future<TripShareLink> shareLink(String tripId) async => TripShareLink.fromJson(_map(await api.post('/trips/$tripId/share', null, true)));
}
