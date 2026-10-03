import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';

import 'driver_location.dart';

/// The Rate card for the city the driver is in (Account › Rate card). Live: `GET /fares/rate-card` at the current GPS
/// fix (the built-in rates when there is no fix in a few seconds); mock mode: the built-in rates.
final rateCardProvider = FutureProvider.autoDispose<RateCard>((ref) async {
  if (!ref.watch(isLiveApiProvider)) return RateCard.demo;
  LatLng? at;
  try {
    at = (await ref.read(driverLocatorProvider).currentFix().timeout(const Duration(seconds: 5))).point;
  } on Object {
    at = null;
  }
  return ref.read(liveJobsProvider).rateCard(at);
});
