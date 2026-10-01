// Rental and outstation rates: the shared cases (test/fixtures/ride_mode_cases.json) must come out exactly as in the
// API (apps/api/src/modules/fares/ride-modes.spec.ts reads the same file).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';

void main() {
  final cases = jsonDecode(File('test/fixtures/ride_mode_cases.json').readAsStringSync()) as Map<String, dynamic>;
  VehicleKind kind(Object? k) => vehicleKindFromApi(k);
  Map<String, Object> settled(ModeSettlement s) =>
      {'extraKm': s.extraKm, 'extraMin': s.extraMin, 'extraKmCharge': s.extraKmCharge, 'extraTimeCharge': s.extraTimeCharge};
  bool same(Object? a, Object? b) => a is num && b is num ? (a - b).abs() < 1e-9 : a == b;

  for (final c in (cases['rental'] as List).cast<Map<String, dynamic>>()) {
    test(c['name'] as String, () {
      final i = (c['input'] as Map).cast<String, dynamic>();
      final e = (c['expected'] as Map).cast<String, dynamic>();
      final t = RideModeRates.rentalTerms(kind(i['kind']), i['packageId'] as String)!;
      final q = RideModeRates.quote(Seed.vehicle(kind(i['kind'])), t, distanceKm: t.km.toDouble(), durationMin: t.hours * 60);
      expect(t.price, e['price']);
      expect(same(t.extraKmRate, e['extraKmRate']), isTrue);
      expect(same(t.extraMinRate, e['extraMinRate']), isTrue);
      expect(q.total, e['total']);
      final s = settled(RideModeRates.settle(t, (i['actualKm'] as num?)?.toDouble(), (i['actualMin'] as num).toDouble()));
      for (final MapEntry(:key, :value) in (e['settlement'] as Map).cast<String, dynamic>().entries) {
        expect(same(s[key], value), isTrue, reason: '$key: ${s[key]} vs $value');
      }
    });
  }

  for (final c in (cases['outstation'] as List).cast<Map<String, dynamic>>()) {
    test(c['name'] as String, () {
      final i = (c['input'] as Map).cast<String, dynamic>();
      final e = (c['expected'] as Map).cast<String, dynamic>();
      final t = RideModeRates.outstationTerms(
        kind(i['kind']),
        routeKm: (i['routeKm'] as num).toDouble(),
        roundTrip: i['roundTrip'] as bool,
        leaveAt: DateTime.parse(i['leaveAt'] as String),
        returnAt: i['returnAt'] == null ? null : DateTime.parse(i['returnAt'] as String),
      );
      final q = RideModeRates.quote(Seed.vehicle(kind(i['kind'])), t, distanceKm: (i['routeKm'] as num).toDouble(), durationMin: 60);
      expect(t.days, e['days']);
      expect(t.includedKm, e['includedKm']);
      expect(same(t.perKm, e['perKm']), isTrue);
      expect(t.allowancePerDay, e['allowancePerDay']);
      expect(q.total, e['total']);
      final s = settled(RideModeRates.settle(t, (i['actualKm'] as num).toDouble(), 600));
      for (final MapEntry(:key, :value) in (e['settlement'] as Map).cast<String, dynamic>().entries) {
        expect(same(s[key], value), isTrue, reason: '$key: ${s[key]} vs $value');
      }
    });
  }

  test('rental terms parse from the API', () {
    final t = ModeTerms.fromJson({'mode': 'RENTAL', 'packageId': '4h', 'hours': 4, 'km': 40, 'price': 979, 'extraKmRate': 14, 'extraMinRate': 2.5});
    expect(t, isA<RentalTerms>());
    expect((t! as RentalTerms).package.label, '4 hrs · 40 km');
    expect(ModeTerms.fromJson(null), isNull);
  });

  test('mode requests send the API what it needs', () {
    expect(const ModeRequest(mode: RideMode.rental, packageId: '4h').toJson(), {'rideMode': 'RENTAL', 'rentalPackageId': '4h'});
    final leave = DateTime.utc(2026, 10, 6, 0, 30);
    final back = DateTime.utc(2026, 10, 7, 14, 30);
    expect(ModeRequest(mode: RideMode.outstation, roundTrip: true, leaveAt: leave, returnAt: back).toJson(), {
      'rideMode': 'OUTSTATION',
      'roundTrip': true,
      'scheduledAt': '2026-10-06T00:30:00.000Z',
      'returnAt': '2026-10-07T14:30:00.000Z',
    });
    // One way never sends a return time.
    expect(ModeRequest(mode: RideMode.outstation, returnAt: back).toJson(), {'rideMode': 'OUTSTATION', 'roundTrip': false});
  });
}
