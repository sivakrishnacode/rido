import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';

/// [p] on a ~2 km grid, so a pickup moving around one city asks for its prices once.
LatLng pricingKey(LatLng p) => LatLng((p.latitude * 50).round() / 50, (p.longitude * 50).round() / 50);

/// The prices for rentals, outstation, goods to another town and house shifting in the city at a [pricingKey]
/// (`GET /fares/rates`; mock mode: the built-in ones). Offline or failing: the built-in prices (quotes still come from
/// the server, so a booked price is always the city's).
final modePricingProvider = FutureProvider.family<ModePricing, LatLng>((ref, at) async {
  try {
    return await ref.read(rideRepositoryProvider).modePricing(at);
  } on Object {
    return ModePricing.defaults;
  }
});

/// The city's prices at [at] for a screen to show (the built-in ones until they load).
ModePricing watchPricing(WidgetRef ref, LatLng at) => ref.watch(modePricingProvider(pricingKey(at))).value ?? ModePricing.defaults;
