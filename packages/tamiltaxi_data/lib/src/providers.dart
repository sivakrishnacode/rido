import 'dart:math' as math;

import 'package:flutter/widgets.dart' show ImageProvider, NetworkImage;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

import 'api/api_client.dart';
import 'api/api_repositories.dart';
import 'api/live_services.dart';
import 'api/push.dart';
import 'api/realtime_client.dart';
import 'api/safety.dart';
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

/// Both apps: trip safety (share links, SOS, "Is everything OK?" answers). Tests override it with a fake.
final liveSafetyProvider = Provider<LiveSafety>((ref) => LiveSafety(ref.watch(apiClientProvider), ref.watch(realtimeProvider)));

/// A driver's verified photo from the API (with the session token), or null (no photo yet, or seed data).
/// Only the driver, admins and riders who had a trip with them may load it.
final driverPhotoProvider = Provider.family<ImageProvider?, String?>((ref, path) {
  if (path == null || !ref.watch(isLiveApiProvider)) return null;
  final api = ref.watch(apiClientProvider);
  return NetworkImage('${api.baseUrl}$path', headers: {if (api.session.token != null) 'authorization': 'Bearer ${api.session.token}'});
});

/// Push notifications (null in mock mode, tests, or builds without Firebase config).
final pushProvider = Provider<TtPush?>((ref) => null);

/// How the apps' providers retry a failed load (`ProviderScope(retry: apiRetry)`): Riverpod's backoff for network
/// trouble, never for an answer the API gave on purpose. A 4xx (429 "too many requests" above all, 404, 403) comes
/// back the same however often it is asked, so the screen shows its message instead of asking again in a loop.
Duration? apiRetry(int retryCount, Object error) {
  if (error is ApiException && error.status >= 400 && error.status < 500) return null;
  return ProviderContainer.defaultRetry(retryCount, error);
}

/// Background settings (app config, service cities) keep trying while the network is down, slowly: 5 s, 10 s, 20 s …
/// up to every 5 minutes, and at least 2 minutes after a 429. Their screens keep working on fallbacks meanwhile.
Duration? backgroundRetry(int retryCount, Object error) {
  if (error is ApiException && error.status >= 400 && error.status < 500 && error.status != 429) return null;
  final seconds = math.min(300, 5 * math.pow(2, math.min(retryCount, 6)).toInt());
  final isTooMany = error is ApiException && error.status == 429;
  return Duration(seconds: isTooMany ? math.max(120, seconds) : seconds);
}

/// Overrides that switch every repository to the Tamil Taxi API (`ProviderScope(overrides: liveApiOverrides(api))`).
List<Override> liveApiOverrides(ApiClient api, {TtPush? push}) => [
      isLiveApiProvider.overrideWithValue(true),
      pushProvider.overrideWithValue(push),
      apiClientProvider.overrideWithValue(api),
      authRepositoryProvider.overrideWith((ref) => ApiAuthRepository(api)),
      placesRepositoryProvider.overrideWith((ref) => ApiPlacesRepository(api)),
      rideRepositoryProvider.overrideWith((ref) => ApiRideRepository(api)),
      parcelRepositoryProvider.overrideWith((ref) => ApiParcelRepository(api)),
      driverRepositoryProvider.overrideWith((ref) => ApiDriverRepository(api)),
      subscriptionRepositoryProvider.overrideWith((ref) => ApiSubscriptionRepository(api)),
      supportRepositoryProvider.overrideWith((ref) => ApiSupportRepository(api)),
    ];
