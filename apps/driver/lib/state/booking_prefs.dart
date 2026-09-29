import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The driver's booking preferences. Live: loaded from and saved to the API (dispatch filters on the server).
/// Mock mode: kept in memory.
class BookingPrefsController extends AsyncNotifier<BookingPrefs> {
  @override
  Future<BookingPrefs> build() async {
    if (!ref.watch(isLiveApiProvider)) return const BookingPrefs();
    return ref.read(liveJobsProvider).bookingPrefs();
  }

  /// Saves [next]; the state becomes what the server stored. Throws on failure (state unchanged).
  Future<void> save(BookingPrefs next) async {
    if (!ref.read(isLiveApiProvider)) {
      state = AsyncData(next);
      return;
    }
    final saved = await ref.read(liveJobsProvider).setBookingPrefs(next);
    if (ref.mounted) state = AsyncData(saved);
  }
}

final bookingPrefsProvider = AsyncNotifierProvider<BookingPrefsController, BookingPrefs>(BookingPrefsController.new);

/// The driver's saved "Home" spot for the go-to destination (on the phone only).
class SavedHomeController extends Notifier<LatLng?> {
  static const _latKey = 'goto_home_lat';
  static const _lngKey = 'goto_home_lng';

  @override
  LatLng? build() {
    unawaited(_load());
    return null;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lat = prefs.getDouble(_latKey);
      final lng = prefs.getDouble(_lngKey);
      if (ref.mounted && lat != null && lng != null) state = LatLng(lat, lng);
    } catch (e) {
      debugPrint('Saved home unavailable: $e');
    }
  }

  Future<void> set(LatLng home) async {
    state = home;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_latKey, home.latitude);
      await prefs.setDouble(_lngKey, home.longitude);
    } catch (_) {}
  }
}

final savedHomeProvider = NotifierProvider<SavedHomeController, LatLng?>(SavedHomeController.new);
