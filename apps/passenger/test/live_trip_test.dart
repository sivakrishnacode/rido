// Pure helpers used when the app follows a real trip (live API mode): API status → phase, ETA from the
// driver's GPS against the stored polyline, stale-update guard, chat merging and map insets.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_passenger/common/launch.dart';
import 'package:rido_passenger/common/map_insets.dart';
import 'package:rido_passenger/state/live_trip.dart';
import 'package:rido_passenger/state/parcel_flow.dart';
import 'package:rido_passenger/state/ride_flow.dart';
import 'package:rido_ui/rido_ui.dart';

ChatMessage _msg(String id, String text, {bool fromMe = true}) =>
    ChatMessage(id: id, text: text, fromMe: fromMe, sentAt: DateTime(2026, 9, 26, 10));

void main() {
  group('ridePhaseForStatus', () {
    test('maps every API status', () {
      expect(ridePhaseForStatus('SEARCHING', RidePhase.searching), RidePhase.searching);
      expect(ridePhaseForStatus('NO_DRIVERS', RidePhase.searching), RidePhase.noDrivers);
      expect(ridePhaseForStatus('DRIVER_ASSIGNED', RidePhase.searching), RidePhase.assigned);
      expect(ridePhaseForStatus('DRIVER_ARRIVED', RidePhase.assigned), RidePhase.arrived);
      expect(ridePhaseForStatus('IN_PROGRESS', RidePhase.arrived), RidePhase.inProgress);
      expect(ridePhaseForStatus('COMPLETED', RidePhase.inProgress), RidePhase.completed);
      expect(ridePhaseForStatus('CANCELLED', RidePhase.assigned), RidePhase.planning);
    });

    test('back to SEARCHING after a driver was assigned is the driver cancelling (S-02)', () {
      expect(ridePhaseForStatus('SEARCHING', RidePhase.assigned), RidePhase.driverCancelled);
      expect(ridePhaseForStatus('SEARCHING', RidePhase.arrived), RidePhase.driverCancelled);
      // Stays on S-02 while dispatch looks again.
      expect(ridePhaseForStatus('SEARCHING', RidePhase.driverCancelled), RidePhase.driverCancelled);
      // A fresh booking is plain searching.
      expect(ridePhaseForStatus('SEARCHING', RidePhase.planning), RidePhase.searching);
    });

    test('ignores parcel-only and unknown statuses', () {
      expect(ridePhaseForStatus('PICKED_UP', RidePhase.inProgress), isNull);
      expect(ridePhaseForStatus('DELIVERED', RidePhase.inProgress), isNull);
      expect(ridePhaseForStatus('SOMETHING_NEW', RidePhase.inProgress), isNull);
    });
  });

  test('parcelPhaseForStatus maps the parcel lifecycle', () {
    expect(parcelPhaseForStatus('SEARCHING'), ParcelPhase.searching);
    expect(parcelPhaseForStatus('NO_DRIVERS'), ParcelPhase.noDrivers);
    expect(parcelPhaseForStatus('DRIVER_ASSIGNED'), ParcelPhase.assigned);
    expect(parcelPhaseForStatus('DRIVER_ARRIVED'), ParcelPhase.atPickup);
    expect(parcelPhaseForStatus('PICKED_UP'), ParcelPhase.inTransit);
    expect(parcelPhaseForStatus('DELIVERED'), ParcelPhase.delivered);
    expect(parcelPhaseForStatus('CANCELLED'), ParcelPhase.planning);
    expect(parcelPhaseForStatus('IN_PROGRESS'), isNull);
  });

  group('trackOnPath', () {
    // A straight 4-point path going north, ~1.1 km per step.
    const path = [LatLng(11.00, 76.96), LatLng(11.01, 76.96), LatLng(11.02, 76.96), LatLng(11.03, 76.96)];

    test('at the start the whole path is left', () {
      final t = trackOnPath(path, path.first);
      expect(t.progress, 0);
      expect(t.remainingKm, closeTo(3.34, 0.05));
    });

    test('snaps to the nearest vertex and measures the rest', () {
      final t = trackOnPath(path, const LatLng(11.0205, 76.9601));
      expect(t.progress, closeTo(2 / 3, 1e-9));
      expect(t.remainingKm, closeTo(1.17, 0.05));
      expect(t.totalKm, closeTo(3.34, 0.05));
    });

    test('at the end nothing is left', () {
      final t = trackOnPath(path, path.last);
      expect(t.progress, 1);
      expect(t.remainingKm, closeTo(0, 1e-6));
    });

    test('empty and single-point paths', () {
      expect(trackOnPath(const [], path.first).remainingKm, 0);
      expect(trackOnPath([path.first], path[1]).progress, 1);
    });
  });

  test('etaMinutes rounds up and never shows 0', () {
    expect(etaMinutes(5, 20), 15);
    expect(etaMinutes(0.1, 20), 1);
    expect(etaMinutes(0, 20), 1);
    expect(etaMinutes(1, 0), 1);
    expect(etaMinutes(2.1, 18), 7, reason: 'floating-point noise does not add a minute');
  });

  test('remainingTripMinutes scales the quoted duration by the route left', () {
    expect(remainingTripMinutes((progress: 0, remainingKm: 4, totalKm: 4), 20), 20);
    expect(remainingTripMinutes((progress: 0.5, remainingKm: 1, totalKm: 4), 20), 5);
    expect(remainingTripMinutes((progress: 1, remainingKm: 0, totalKm: 4), 20), 1);
    expect(remainingTripMinutes((progress: 0, remainingKm: 0, totalKm: 0), 12), 12);
  });

  test('headingFor keeps the old heading when the driver has not moved', () {
    const a = LatLng(11.0, 76.96);
    expect(headingFor(null, a, 42), 42);
    expect(headingFor(a, a, 42), 42);
    expect(headingFor(a, const LatLng(11.01, 76.96), 42), closeTo(0, 0.5));
  });

  test('late, older statuses are dropped; real backward moves are kept', () {
    expect(isStaleStatus('DRIVER_ASSIGNED', 'DRIVER_ARRIVED'), isTrue);
    expect(isStaleStatus('IN_PROGRESS', 'COMPLETED'), isTrue);
    expect(isStaleStatus('SEARCHING', 'CANCELLED'), isTrue);
    expect(isStaleStatus('SEARCHING', 'IN_PROGRESS'), isTrue);
    expect(isStaleStatus('DRIVER_ARRIVED', 'DRIVER_ASSIGNED'), isFalse);
    expect(isStaleStatus('CANCELLED', 'DRIVER_ARRIVED'), isFalse);
    expect(isStaleStatus('DRIVER_ASSIGNED', 'DRIVER_ASSIGNED'), isFalse);
    expect(isStaleStatus('DRIVER_ASSIGNED', null), isFalse);
    // Driver cancelled after accepting, dispatch retrying after no drivers.
    expect(isStaleStatus('SEARCHING', 'DRIVER_ASSIGNED'), isFalse);
    expect(isStaleStatus('SEARCHING', 'NO_DRIVERS'), isFalse);
  });

  test('apiErrorMessage shows the API message and a friendly offline text', () {
    expect(apiErrorMessage(const ApiException(400, "Rido isn't in this area yet")), "Rido isn't in this area yet");
    expect(apiErrorMessage(const OfflineException()), contains('offline'));
    expect(apiErrorMessage(StateError('x')), 'Something went wrong. Please try again.');
  });

  group('chat', () {
    test('a pushed copy of my message replaces the pending local one', () {
      final chat = [_msg('s1', 'Hi', fromMe: false), _msg('local-1', 'On my way')];
      final merged = mergeChat(chat, _msg('s2', 'On my way'));
      expect(merged.map((m) => m.id), ['s1', 's2']);
    });

    test('duplicates are ignored and driver messages are appended', () {
      final chat = [_msg('s1', 'Hi', fromMe: false)];
      expect(mergeChat(chat, _msg('s1', 'Hi', fromMe: false)), same(chat));
      expect(mergeChat(chat, _msg('s3', 'Coming', fromMe: false)).length, 2);
    });

    test('history comes first; unsent local messages stay at the end', () {
      final current = [_msg('local-1', 'Where are you?'), _msg('local-2', 'Already sent')];
      final history = [_msg('s1', 'Hello', fromMe: false), _msg('s2', 'Already sent')];
      expect(chatWithHistory(current, history).map((m) => m.id), ['s1', 's2', 'local-1']);
    });
  });

  test('sheetMapInsets leaves flutter_map untouched and shifts the fit for Google', () {
    RidoMap.tilesEnabled = false; // flutter_map engine, as in every widget test
    const fit = EdgeInsets.fromLTRB(56, 96, 56, 500);
    final flat = sheetMapInsets(fit, 500);
    expect(flat.map, EdgeInsets.zero);
    expect(flat.fit, fit);
  });

  test('tripShareText names the driver, plate, vehicle and drop', () {
    const driver = DriverProfile(
      id: 'd1',
      name: 'Karthik S',
      phone: '+919876543210',
      vehicleKind: VehicleKind.bike,
      vehicleModel: 'Honda Activa',
      vehicleColor: 'Grey',
      plate: 'TN 37 AB 1234',
      rating: 4.8,
      rides: 10,
      upiId: 'k@upi',
      gender: Gender.male,
    );
    final text = tripShareText(
      riderName: 'Priya',
      driver: driver,
      vehicleLabel: 'Bike',
      drop: Seed.brookefields,
      vehicleAt: const LatLng(11.01, 76.96),
    );
    expect(text, contains("Priya's Rido ride to ${Seed.brookefields.name}"));
    expect(text, contains('Karthik S'));
    expect(text, contains('TN 37 AB 1234'));
    expect(text, contains('Grey Honda Activa (Bike)'));
    expect(text, contains('https://maps.google.com/?q=11.01000,76.96000'));
    expect(text, isNot(contains('+919876543210')));
  });
}
