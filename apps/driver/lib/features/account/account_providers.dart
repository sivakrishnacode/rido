import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rido_data/rido_data.dart';

/// Emergency contact of the signed-in driver ("Lakshmi (Wife)" on D-26 and the SOS screen).
final driverEmergencyContactProvider = FutureProvider<EmergencyContact>((ref) {
  ref.watch(mockDatabaseProvider);
  return ref.watch(driverRepositoryProvider).emergencyContact();
});
