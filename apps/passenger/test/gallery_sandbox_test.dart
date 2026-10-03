// The Design gallery ships in live builds too: a frame's buttons must never act on the signed-in account.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';
import 'package:tamiltaxi_passenger/router/routes.dart';
import 'package:tamiltaxi_ui/tamiltaxi_ui.dart';

import 'support/harness.dart';

class _RecordingTrips extends LiveTrips {
  _RecordingTrips(super.api, super.realtime);
  final calls = <String>[];

  @override
  Future<LiveTripUpdate> book({
    required TripKind kind,
    required VehicleKind vehicle,
    required Place pickup,
    required Place drop,
    PaymentMode paymentMode = PaymentMode.cash,
    ParcelDetails? parcel,
    WomenDriverPref womenDriver = WomenDriverPref.none,
    OtherRider? rider,
    ModeRequest? mode,
    ShiftingDetails? shifting,
    DateTime? slot,
  }) async {
    calls.add('book');
    throw const OfflineException();
  }
}

void main() {
  testWidgets('live: PP-06 "Book" in the gallery books nothing on the account', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await tester.runAsync(SharedPreferences.getInstance);
    final api = ApiClient(baseUrl: 'http://localhost:0/v1', session: ApiSession(prefs!));
    final trips = _RecordingTrips(api, RealtimeClient(api));
    await pumpRoute(tester, Routes.galleryView('PP-06'), overrides: [
      isLiveApiProvider.overrideWithValue(true),
      apiClientProvider.overrideWithValue(api),
      liveTripsProvider.overrideWithValue(trips),
    ]);
    final book = find.descendant(of: find.byType(TtButton), matching: find.textContaining('Book')).first;
    await tester.ensureVisible(book);
    await tester.tap(book);
    await tester.pump(const Duration(seconds: 1));
    expect(trips.calls, isEmpty);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 1));
  });
}
