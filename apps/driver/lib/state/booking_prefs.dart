import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';

/// The driver's booking preferences, Go To / Stay In and saved areas included. Live: loaded from and saved to the
/// API (dispatch filters on the server). Mock mode: kept in memory.
class BookingPrefsController extends AsyncNotifier<BookingPrefs> {
  @override
  Future<BookingPrefs> build() async {
    if (!ref.watch(isLiveApiProvider)) return const BookingPrefs();
    return withoutExpired(await ref.read(liveJobsProvider).bookingPrefs(), DateTime.now());
  }

  /// Saves [next]; the state becomes what the server stored. Throws on failure (state unchanged). A Go To / Stay In
  /// whose time is up is dropped first: sent back, the server would start a fresh one.
  Future<void> save(BookingPrefs next) async {
    final send = withoutExpired(next, DateTime.now());
    if (!ref.read(isLiveApiProvider)) {
      state = AsyncData(send);
      return;
    }
    final saved = await ref.read(liveJobsProvider).setBookingPrefs(send);
    if (ref.mounted) state = AsyncData(saved);
  }

  /// Saves [update] of the preferences as loaded (Home's Go To / Stay In, the saved areas). Throws on failure.
  Future<void> change(BookingPrefs Function(BookingPrefs current) update) async =>
      save(update(withoutExpired(await future, DateTime.now())));

  /// Adds [area] to the saved ones, replacing one with the same name ("Home" moved) or place.
  Future<void> saveArea(SavedArea area) => change((p) {
        final others = [for (final a in p.areas) if (a.name != area.name && !a.isAt(area.location)) a];
        return p.copyWith(areas: [area, ...others].take(BookingPrefs.maxAreas).toList());
      });

  Future<void> removeArea(SavedArea area) => change((p) => p.copyWith(areas: [for (final a in p.areas) if (a != area) a]));

  /// Services: [service] on (a pause ends), or off for [pauseFor] (it comes back by itself) or, null, until switched on
  /// again, with an optional [reason]; Packers & Movers on with the [helpers] they bring. Throws on failure.
  Future<void> setService(DriverService service, {required bool on, Duration? pauseFor, String? reason, int? helpers}) async {
    if (ref.read(isLiveApiProvider)) {
      final saved = await ref
          .read(liveJobsProvider)
          .setService(service, on: on, pauseMinutes: pauseFor?.inMinutes, reason: reason, helpers: helpers);
      if (ref.mounted) state = AsyncData(saved);
      return;
    }
    // Mock mode: the same rules as the server, in memory.
    final p = withoutExpired(await future, DateTime.now());
    final pauses = {...p.pauses}..remove(service);
    if (!on) pauses[service] = ServicePause(until: pauseFor == null ? null : DateTime.now().add(pauseFor), reason: reason);
    final value = on || pauseFor != null;
    state = AsyncData(p.copyWith(
      pauses: pauses,
      parcels: service == DriverService.parcels ? value : null,
      rentals: service == DriverService.rentals ? value : null,
      outstation: service == DriverService.outstation ? value : null,
      shifting: service == DriverService.shifting ? value : null,
      helpers: service == DriverService.shifting && on ? helpers : null,
    ));
  }
}

final bookingPrefsProvider = AsyncNotifierProvider<BookingPrefsController, BookingPrefs>(BookingPrefsController.new);

/// [prefs] without a Go To / Stay In that ended before [now] (the server switched it off by then).
BookingPrefs withoutExpired(BookingPrefs prefs, DateTime now) {
  bool over(DateTime? until) => until != null && !until.isAfter(now);
  final goToOver = prefs.goTo != null && over(prefs.goTo!.until);
  final stayInOver = prefs.stayIn != null && over(prefs.stayIn!.until);
  if (!goToOver && !stayInOver) return prefs;
  return prefs.copyWith(goTo: goToOver ? () => null : null, stayIn: stayInOver ? () => null : null);
}

/// "Towards Home" / "Inside RS Puram" while Go To / Stay In is on at [now] (the request card tag), else null.
String? directionTag(BookingPrefs? prefs, DateTime now) {
  bool running(DateTime? until) => until == null || until.isAfter(now);
  final goTo = prefs?.goTo;
  final stayIn = prefs?.stayIn;
  if (goTo != null && running(goTo.until)) return 'Towards ${goTo.name}';
  if (stayIn != null && running(stayIn.until)) return 'Inside ${stayIn.name}';
  return null;
}
