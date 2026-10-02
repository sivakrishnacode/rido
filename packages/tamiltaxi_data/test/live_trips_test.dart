import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';

/// A socket the test pushes events into.
class _Socket extends RealtimeClient {
  _Socket(super.api);
  final pushed = StreamController<RealtimeEvent>.broadcast();

  @override
  void connect() {}

  @override
  Stream<Map<String, dynamic>> on(String name) => pushed.stream.where((e) => e.name == name).map((e) => e.data);
}

void main() {
  test('trip.no_drivers ends the search without waiting for a poll (the API may be unreachable)', () async {
    var polls = 0;
    SharedPreferences.setMockInitialValues({});
    final api = ApiClient(
      baseUrl: 'http://api.test/v1',
      session: await ApiSession.load(),
      client: MockClient((req) async {
        polls++;
        throw http.ClientException('no network');
      }),
    );
    final socket = _Socket(api);
    final trips = LiveTrips(api, socket);
    final got = <LiveTripUpdate>[];
    final sub = trips.updates('t1').listen(got.add);
    socket.pushed
      ..add(const RealtimeEvent('trip.no_drivers', {'tripId': 'other'}))
      ..add(const RealtimeEvent('trip.no_drivers', {'tripId': 't1'}));
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(got, hasLength(1));
    expect(got.single.trip.id, 't1');
    expect(got.single.isNoDrivers, isTrue);
    expect(got.single.cancelledBy, CancelledBy.system);
    expect(polls, 0);
  });
}
