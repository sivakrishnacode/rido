// Trips the app isn't following: a trip booked for later that starts its search (or gets a driver) while the app is
// open is followed and opened; a tapped "rate your ride" push for a finished trip opens its payment / rating.
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';
import 'package:tamiltaxi_passenger/router/routes.dart';
import 'package:tamiltaxi_passenger/state/ride_flow.dart';
import 'package:tamiltaxi_passenger/state/session_actions.dart';

import 'support/harness.dart';

Map<String, dynamic> _trip(String id, String status, {int? rating}) => {
      'id': id,
      'kind': 'RIDE',
      'status': status,
      'vehicleKind': 'SEDAN',
      'rideMode': 'OUTSTATION',
      'pickupName': 'Gandhipuram',
      'pickupAddr': 'Cross Cut Rd',
      'pickupLat': 11.0183,
      'pickupLng': 76.9725,
      'dropName': 'Ooty',
      'dropAddr': 'The Nilgiris',
      'dropLat': 11.41,
      'dropLng': 76.69,
      'distanceKm': 86,
      'durationMin': 150,
      'fareTotal': 1890,
      'otp': '4821',
      'createdAt': '2026-10-02T05:30:00.000Z',
      'rating': ?rating,
      if (status != 'SEARCHING')
        'driver': {
          'id': 'd1',
          'vehicleKind': 'SEDAN',
          'plate': 'TN 37 AB 1234',
          'user': {'name': 'Karthik S', 'phone': '+919876500002'},
        },
    };

/// A socket the test pushes events into (always "connected", so no polling).
class _Socket extends RealtimeClient {
  _Socket(super.api);
  final pushed = StreamController<RealtimeEvent>.broadcast();
  @override
  void connect() {}
  @override
  bool get isConnected => true;
  @override
  Stream<bool> get connection => const Stream.empty();
  @override
  Future<bool> joinTrip(String tripId) async => true;
  @override
  Stream<Map<String, dynamic>> on(String name) => pushed.stream.where((e) => e.name == name).map((e) => e.data);
}

/// GET /trips/:id answers from [trips]; there is no active trip.
class _Trips extends LiveTrips {
  _Trips(super.api, super.realtime);
  final trips = <String, Map<String, dynamic>>{};
  @override
  Future<LiveTripUpdate> poll(String tripId) async => LiveTripUpdate.fromJson(trips[tripId]!);
  @override
  Future<LiveTripUpdate?> active() async => null;
  @override
  Future<List<ChatMessage>> chatHistory(String tripId) async => const [];
}

Future<(List<Override>, _Socket, _Trips)> _live(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await tester.runAsync(SharedPreferences.getInstance);
  final api = ApiClient(baseUrl: 'http://localhost:0/v1', session: ApiSession(prefs!));
  final socket = _Socket(api);
  final trips = _Trips(api, socket);
  return (
    [
      isLiveApiProvider.overrideWithValue(true),
      apiClientProvider.overrideWithValue(api),
      realtimeProvider.overrideWithValue(socket),
      liveTripsProvider.overrideWithValue(trips),
    ],
    socket,
    trips,
  );
}

String _location(WidgetTester tester) {
  final router = GoRouter.of(tester.element(find.byType(Navigator).first));
  return router.routerDelegate.currentConfiguration.uri.path;
}

void main() {
  testWidgets('a trip booked for later that starts searching while the app is open is followed and opened', (tester) async {
    final (overrides, socket, _) = await _live(tester);
    final container = await pumpRoute(tester, Routes.activity, overrides: overrides);

    // Not on yet (an edit to the booking): nothing opens.
    socket.pushed.add(RealtimeEvent('trip.updated', _trip('t-later', 'SCHEDULED')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(_location(tester), Routes.activity);

    socket.pushed.add(RealtimeEvent('trip.updated', _trip('t-later', 'SEARCHING')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(container.read(rideFlowProvider).tripId, 't-later');
    expect(container.read(rideFlowProvider).phase, RidePhase.searching);
    expect(_location(tester), Routes.findingDriver);

    // The driver accepts: the followed flow moves on.
    socket.pushed.add(RealtimeEvent('trip.updated', _trip('t-later', 'DRIVER_ASSIGNED')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(seconds: 1));
    expect(container.read(rideFlowProvider).phase, RidePhase.assigned);
    expect(container.read(rideFlowProvider).driver.name, 'Karthik S');
    // Stop following (its poll timer), then leave the screens.
    container.invalidate(rideFlowProvider);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('"Tap to rate your ride" after the app was closed opens P-19; once rated, the trip details', (tester) async {
    final (overrides, _, trips) = await _live(tester);
    trips.trips['t-done'] = _trip('t-done', 'COMPLETED');
    trips.trips['t-rated'] = _trip('t-rated', 'COMPLETED', rating: 5);
    late WidgetRef ref;
    await loadTestFonts();
    await tester.pumpWidget(ProviderScope(
      overrides: overrides,
      child: Consumer(builder: (context, r, _) {
        ref = r;
        return const SizedBox();
      }),
    ));

    expect(await routeForTripPush(ref, {'type': 'trip', 'tripId': 't-rated', 'status': 'COMPLETED'}), Routes.tripDetails('t-rated'));
    expect(await routeForTripPush(ref, {'type': 'trip', 'tripId': 't-done', 'status': 'COMPLETED'}), Routes.rideCompleted);
    expect(ref.read(rideFlowProvider).driver.name, 'Karthik S');
    // Tapped again: the trip is followed now, nothing is fetched again.
    trips.trips.clear();
    expect(await routeForTripPush(ref, {'type': 'chat', 'tripId': 't-done'}), Routes.rideCompleted);
    await tester.pumpWidget(const SizedBox());
  });
}
