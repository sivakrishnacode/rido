import 'package:rido_data/rido_data.dart';

/// [LiveSafety] without a network: answers (or fails) and records the calls.
class FakeSafety implements LiveSafety {
  FakeSafety({this.failShare = false, this.failSos = false, this.shareUrl = 'https://admin.rido.test/track/trip1.abc.SIGNATURE'});

  final bool failShare;
  bool failSos;
  final String shareUrl;
  int shareCalls = 0;
  final sosCalls = <({String tripId, LatLng? at})>[];

  @override
  ApiClient get api => throw UnimplementedError();

  @override
  Future<TripShareLink> shareLink(String tripId) async {
    shareCalls++;
    if (failShare) throw const ApiException(503, 'offline');
    return TripShareLink(url: shareUrl, expiresAt: DateTime(2026, 9, 28, 23));
  }

  @override
  Future<SosAlert> sos(String tripId, {LatLng? at, String? note}) async {
    sosCalls.add((tripId: tripId, at: at));
    if (failSos) throw const OfflineException();
    return SosAlert(id: 'sos-1', status: 'OPEN', shareUrl: shareUrl);
  }
}
