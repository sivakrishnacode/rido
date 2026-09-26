import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rido_data/rido_data.dart';

/// Live API: the demand hotspots and service-area outline for the driver's Home map, refreshed every two minutes
/// while Home is showing it (the API caches it for a minute, so drivers polling costs almost nothing). Null until
/// the first answer, and in mock mode.
class DemandMapController extends Notifier<DemandMap?> {
  static const refreshEvery = Duration(minutes: 2);
  Timer? _timer;

  @override
  DemandMap? build() {
    if (!ref.read(isLiveApiProvider)) return null;
    ref.onDispose(() => _timer?.cancel());
    _timer = Timer.periodic(refreshEvery, (_) => unawaited(refresh()));
    unawaited(refresh());
    return null;
  }

  Future<void> refresh() async {
    try {
      final map = await ref.read(liveJobsProvider).demandMap();
      if (ref.mounted) state = map;
    } catch (e) {
      debugPrint('Demand map unavailable: $e');
    }
  }
}

/// Watched by Home only, so the refresh timer stops when Home is gone.
final demandMapProvider = NotifierProvider.autoDispose<DemandMapController, DemandMap?>(DemandMapController.new);
