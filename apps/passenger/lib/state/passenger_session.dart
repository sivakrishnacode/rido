import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rido_data/rido_data.dart';

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
  Future<PassengerProfile> build() {
    ref.watch(mockDatabaseProvider);
    return ref.read(authRepositoryProvider).profile();
  }

  PassengerProfile get _p => state.value ?? Seed.priya;

  Future<void> save(PassengerProfile p) async {
    state = AsyncData(p);
    await ref.read(authRepositoryProvider).updateProfile(p);
  }

  Future<void> setBasics({required String name, String? email, Gender? gender}) =>
      save(_p.copyWith(name: name, email: email, gender: gender));

  Future<void> addContact(EmergencyContact c) =>
      save(_p.copyWith(emergencyContacts: [..._p.emergencyContacts, c].take(3).toList()));

  Future<void> removeContact(String id) =>
      save(_p.copyWith(emergencyContacts: _p.emergencyContacts.where((c) => c.id != id).toList()));

  Future<void> setAutoShare(bool v) => save(_p.copyWith(autoShareTrips: v));

  Future<void> setPreferWomenDriver(bool v) => save(_p.copyWith(preferWomenDriver: v));

  Future<void> saveSavedPlace(SavedPlace place) async {
    final list = await ref.read(placesRepositoryProvider).saveSavedPlace(place);
    state = AsyncData(_p.copyWith(savedPlaces: list));
  }

  Future<void> removeSavedPlace(String id) async {
    final list = await ref.read(placesRepositoryProvider).removeSavedPlace(id);
    state = AsyncData(_p.copyWith(savedPlaces: list));
  }
}

final passengerProfileProvider =
    AsyncNotifierProvider<PassengerProfileController, PassengerProfile>(PassengerProfileController.new);
