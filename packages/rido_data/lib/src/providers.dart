import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'demo_settings.dart';
import 'mock/mock_database.dart';
import 'mock/mock_repositories.dart';
import 'repositories/repositories.dart';

/// In-memory seed store. `ref.invalidate(mockDatabaseProvider)` resets all seed data.
///
/// To use a real API, override the repository providers below in `ProviderScope(overrides: …)`
/// with HTTP implementations; no screen needs to change.
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
