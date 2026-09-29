import 'dart:async';

import 'package:tamiltaxi_data/tamiltaxi_data.dart';

/// [LiveSafety] without a network: answers (or fails) and records the calls.
class FakeSafety implements LiveSafety {
  FakeSafety({this.failShare = false, this.failSos = false, this.shareUrl = 'https://admin.tamiltaxi.test/track/trip1.abc.SIGNATURE'});

  final bool failShare;
  bool failSos;
  final String shareUrl;
  int shareCalls = 0;
  final sosCalls = <({String tripId, LatLng? at})>[];

  final answers = <({String kind, String? eventId, bool ok})>[];
  final _checks = StreamController<SafetyCheck>.broadcast();
  bool failAnswer = false;

  @override
  ApiClient get api => throw UnimplementedError();

  @override
  RealtimeClient? get realtime => null;

  /// Sends [check] as if the server emitted `safety.check`.
  void emit(SafetyCheck check) => _checks.add(check);

  @override
  Stream<SafetyCheck> checks() => _checks.stream;

  @override
  Future<SosAlert?> answer(SafetyCheck check, {required bool ok, LatLng? at}) async {
    answers.add((kind: check.kind, eventId: check.eventId, ok: ok));
    if (failAnswer) throw const OfflineException();
    return ok ? null : SosAlert(id: 'sos-2', status: 'OPEN', shareUrl: shareUrl);
  }

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
