import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

import 'api/api_client.dart';
import 'api/api_repositories.dart';
import 'api/live_services.dart';
import 'api/realtime_client.dart';
import 'demo_settings.dart';
import 'mock/mock_database.dart';
import 'mock/mock_repositories.dart';
import 'repositories/repositories.dart';

/// In-memory seed store. `ref.invalidate(mockDatabaseProvider)` resets all seed data.
///
/// The apps' `main()` overrides the repository providers below with the API implementations
/// ([liveApiOverrides]); widget tests and the design gallery keep these seed-data mocks.
final mockDatabaseProvider = Provider<MockDatabase>((ref) => MockDatabase());

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => MockAuthRepository(ref.watch(mockDatabaseProvider), () => ref.read(demoSettingsProvider)),
);

final placesRepositoryProvider = Provider<PlacesRepository>(
  (ref) => MockPlacesRepository(ref.watch(mockDatabaseProvider), () => ref.read(demoSettingsProvider)),
);

final rideRepositoryProvider = Provider<RideRepository>(
  (ref) => MockRideRepository(ref.watch(mockDatabaseProvider), () => ref.read(demoSettingsProvider)),
);

final parcelRepositoryProvider = Provider<ParcelRepository>(
  (ref) => MockParcelRepository(ref.watch(mockDatabaseProvider), () => ref.read(demoSettingsProvider)),
);

final driverRepositoryProvider = Provider<DriverRepository>(
  (ref) => MockDriverRepository(ref.watch(mockDatabaseProvider), () => ref.read(demoSettingsProvider)),
);

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>(
  (ref) => MockSubscriptionRepository(
    ref.watch(mockDatabaseProvider),
    () => ref.read(demoSettingsProvider),
    onPaymentAttempt: () =>
        ref.read(demoSettingsProvider.notifier).update((s) => s.copyWith(failNextPayment: false)),
  ),
);

final supportRepositoryProvider = Provider<SupportRepository>(
  (ref) => MockSupportRepository(ref.watch(mockDatabaseProvider), () => ref.read(demoSettingsProvider)),
);

/// Resets every seed value and demo switch.
void resetAllSeedData(WidgetRef ref) {
  ref.invalidate(mockDatabaseProvider);
  ref.read(demoSettingsProvider.notifier).reset();
}

// ------------------------------------------------------------------------------------------------ live API

/// True when the app talks to the backend ([liveApiOverrides]); false for seed data and the trip simulator.
final isLiveApiProvider = Provider<bool>((ref) => false);

/// Set by [liveApiOverrides].
final apiClientProvider = Provider<ApiClient>((ref) => throw StateError('apiClientProvider needs liveApiOverrides'));

final realtimeProvider = Provider<RealtimeClient>((ref) {
  final client = RealtimeClient(ref.watch(apiClientProvider));
  ref.onDispose(client.dispose);
  return client;
});

/// Passenger: book and follow real trips.
final liveTripsProvider = Provider<LiveTrips>((ref) => LiveTrips(ref.watch(apiClientProvider), ref.watch(realtimeProvider)));

/// Driver: offers, jobs, GPS and chat.
final liveJobsProvider = Provider<LiveJobs>((ref) => LiveJobs(ref.watch(apiClientProvider), ref.watch(realtimeProvider)));

/// Overrides that switch every repository to the Rido API (`ProviderScope(overrides: liveApiOverrides(api))`).
List<Override> liveApiOverrides(ApiClient api) => [
      isLiveApiProvider.overrideWithValue(true),
      apiClientProvider.overrideWithValue(api),
      authRepositoryProvider.overrideWith((ref) => ApiAuthRepository(api)),
      placesRepositoryProvider.overrideWith((ref) => ApiPlacesRepository(api)),
      rideRepositoryProvider.overrideWith((ref) => ApiRideRepository(api)),
      parcelRepositoryProvider.overrideWith((ref) => ApiParcelRepository(api)),
      driverRepositoryProvider.overrideWith((ref) => ApiDriverRepository(api)),
      subscriptionRepositoryProvider.overrideWith((ref) => ApiSubscriptionRepository(api)),
      supportRepositoryProvider.overrideWith((ref) => ApiSupportRepository(api)),
    ];
