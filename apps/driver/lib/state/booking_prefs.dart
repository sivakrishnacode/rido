import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';

/// The driver's booking preferences, Go To / Stay In and saved areas included. Live: loaded from and saved to the
/// API (dispatch filters on the server). Mock mode: kept in memory.
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

  /// Saves [update] of the preferences as loaded (Home's Go To / Stay In, the saved areas). Throws on failure.
  Future<void> change(BookingPrefs Function(BookingPrefs current) update) async => save(update(await future));

  /// Adds [area] to the saved ones, replacing one with the same name ("Home" moved) or place.
  Future<void> saveArea(SavedArea area) => change((p) {
        final others = [for (final a in p.areas) if (a.name != area.name && !a.isAt(area.location)) a];
        return p.copyWith(areas: [area, ...others].take(BookingPrefs.maxAreas).toList());
      });

  Future<void> removeArea(SavedArea area) => change((p) => p.copyWith(areas: [for (final a in p.areas) if (a != area) a]));
}

final bookingPrefsProvider = AsyncNotifierProvider<BookingPrefsController, BookingPrefs>(BookingPrefsController.new);

/// "Towards Home" / "Inside RS Puram" while Go To / Stay In is on at [now] (the request card tag), else null.
String? directionTag(BookingPrefs? prefs, DateTime now) {
  bool running(DateTime? until) => until == null || until.isAfter(now);
  final goTo = prefs?.goTo;
  final stayIn = prefs?.stayIn;
  if (goTo != null && running(goTo.until)) return 'Towards ${goTo.name}';
  if (stayIn != null && running(stayIn.until)) return 'Inside ${stayIn.name}';
  return null;
}
