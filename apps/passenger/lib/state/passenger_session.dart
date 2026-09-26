import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rido_data/rido_data.dart';

import 'app_notice.dart';
import 'live_trip.dart';

/// Activity list (rides + parcels), newest first. Invalidate after adding a trip.
final tripHistoryProvider = FutureProvider<List<Trip>>((ref) {
  ref.watch(mockDatabaseProvider);
  ref.watch(demoSettingsProvider.select((s) => (s.emptyActivity, s.offline, s.slowLoading)));
  return ref.watch(rideRepositoryProvider).history();
});

/// One trip by id (P-22).
final tripByIdProvider = FutureProvider.family<Trip?, String>((ref, id) {
  ref.watch(tripHistoryProvider);
  return ref.watch(rideRepositoryProvider).tripById(id);
});

/// Recent parcels on PP-01.
final recentParcelsProvider = FutureProvider<List<Trip>>((ref) {
  ref.watch(tripHistoryProvider);
  return ref.watch(parcelRepositoryProvider).recentParcels();
});

/// Recent destinations on P-07.
final recentDestinationsProvider = FutureProvider<List<Place>>((ref) {
  ref.watch(demoSettingsProvider.select((s) => (s.offline, s.slowLoading)));
  return ref.watch(placesRepositoryProvider).recentDestinations();
});

/// Support tickets ("My tickets").
final ticketsProvider = FutureProvider<List<SupportTicket>>((ref) {
  ref.watch(demoSettingsProvider.select((s) => (s.offline, s.slowLoading)));
  return ref.watch(supportRepositoryProvider).tickets();
});

/// The signed-in passenger. Mutations write through the AuthRepository.
class PassengerProfileController extends AsyncNotifier<PassengerProfile> {
  @override
  Future<PassengerProfile> build() async {
    ref.watch(mockDatabaseProvider);
    final p = await ref.read(authRepositoryProvider).profile();
    // A signed-in account that never finished P-05 has no name yet; initials need one.
    return p.name.trim().isEmpty ? p.copyWith(name: kPlaceholderName) : p;
  }

  /// The loaded profile (waits for it; never saves over the server with a placeholder).
  Future<PassengerProfile?> _current() async {
    final v = state.value;
    if (v != null) return v;
    try {
      return await future;
    } catch (e) {
      _fail(e);
      return null;
    }
  }

  void _fail(Object e) => ref.read(appNoticeProvider.notifier).show("Couldn't save. ${apiErrorMessage(e)}");

  /// Saves through the AuthRepository and keeps what it returns (server ids for new contacts).
  /// Shows a notice and restores the previous profile on failure. True when saved.
  Future<bool> save(PassengerProfile p) async {
    final before = state;
    state = AsyncData(p);
    try {
      final saved = await ref.read(authRepositoryProvider).updateProfile(p);
      state = AsyncData(saved.name.trim().isEmpty ? saved.copyWith(name: kPlaceholderName) : saved);
      return true;
    } catch (e) {
      state = before;
      _fail(e);
      return false;
    }
  }

  Future<bool> _update(PassengerProfile Function(PassengerProfile p) change) async {
    final p = await _current();
    return p != null && await save(change(p));
  }

  Future<bool> setBasics({required String name, String? email, Gender? gender}) =>
      _update((p) => p.copyWith(name: name, email: email, gender: gender));

  Future<bool> addContact(EmergencyContact c) =>
      _update((p) => p.copyWith(emergencyContacts: [...p.emergencyContacts, c].take(3).toList()));

  Future<bool> removeContact(String id) =>
      _update((p) => p.copyWith(emergencyContacts: p.emergencyContacts.where((c) => c.id != id).toList()));

  Future<bool> setAutoShare(bool v) => _update((p) => p.copyWith(autoShareTrips: v));

  Future<bool> setPreferWomenDriver(bool v) => _update((p) => p.copyWith(preferWomenDriver: v));

  Future<bool> saveSavedPlace(SavedPlace place) async {
    final p = await _current();
    if (p == null) return false;
    try {
      final list = await ref.read(placesRepositoryProvider).saveSavedPlace(place);
      state = AsyncData((state.value ?? p).copyWith(savedPlaces: list));
      return true;
    } catch (e) {
      _fail(e);
      return false;
    }
  }

  Future<bool> removeSavedPlace(String id) async {
    final p = await _current();
    if (p == null) return false;
    try {
      final list = await ref.read(placesRepositoryProvider).removeSavedPlace(id);
      state = AsyncData((state.value ?? p).copyWith(savedPlaces: list));
      return true;
    } catch (e) {
      _fail(e);
      return false;
    }
  }
}

final passengerProfileProvider = AsyncNotifierProvider<PassengerProfileController, PassengerProfile>(
  PassengerProfileController.new,
);

/// Name shown before the passenger has set one (and while the profile loads with the live API).
const kPlaceholderName = 'Rider';

/// Stand-in while the real profile loads (live API); mock mode keeps the seeded passenger.
const kLoadingProfile = PassengerProfile(name: kPlaceholderName, phone: '', gender: Gender.preferNotToSay);

/// The signed-in passenger for display: the loaded profile, or a placeholder while it loads.
final currentProfileProvider = Provider<PassengerProfile>((ref) {
  final loaded = ref.watch(passengerProfileProvider).value;
  if (loaded != null) return loaded;
  return ref.watch(isLiveApiProvider) ? kLoadingProfile : Seed.priya;
});
