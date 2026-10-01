// Goods to another town and house shifting: the shared cases (test/fixtures/goods_mode_cases.json) must come out
// exactly as in the API (apps/api/src/modules/fares/goods-modes.spec.ts reads the same file).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';

void main() {
  final cases = jsonDecode(File('test/fixtures/goods_mode_cases.json').readAsStringSync()) as Map<String, dynamic>;

  group('goods to another town (shared cases)', () {
    for (final c in (cases['goodsOutstation'] as List).cast<Map<String, dynamic>>()) {
      test(c['name'] as String, () {
        final i = (c['input'] as Map).cast<String, dynamic>();
        final e = (c['expected'] as Map).cast<String, dynamic>();
        final kind = vehicleKindFromApi(i['kind']);
        final t = GoodsModeRates.outstationTerms(kind, (i['routeKm'] as num).toDouble());
        expect(t.roundTrip, isFalse);
        expect(t.allowancePerDay, 0);
        expect(t.includedKm, e['includedKm']);
        expect(t.perKm, (e['perKm'] as num).toDouble());
        expect(t.routeKm, closeTo((e['routeKm'] as num).toDouble(), 1e-9));
        expect(RideModeRates.quote(Seed.vehicle(kind), t, distanceKm: t.routeKm, durationMin: 120).total, e['total']);
      });
    }
  });

  group('house shifting (shared cases)', () {
    for (final c in (cases['shifting'] as List).cast<Map<String, dynamic>>()) {
      test(c['name'] as String, () {
        final i = (c['input'] as Map).cast<String, dynamic>();
        final d = ShiftingDetails.fromJson(i['details'])!;
        final lines = GoodsModeRates.lines(d, i['transport'] as int, DateTime.parse(i['at'] as String));
        expect(lines.toJson(), (c['expected'] as Map).cast<String, int>());
      });
    }
  });

  test('goods trucks only; the suggested vehicle follows the home size', () {
    expect(GoodsModeRates.isGoodsTruck(VehicleKind.goodsBike), isFalse);
    expect(GoodsModeRates.goodsTrucks, [VehicleKind.threeWheeler, VehicleKind.miniTruck, VehicleKind.pickup, VehicleKind.truck]);
    final q = GoodsModeRates.quote(Seed.gandhipuram, Seed.brookefields, const ShiftingDetails(homeSize: HomeSize.twoBhk),
        at: DateTime(2026, 10, 7, 9), now: DateTime(2026, 10, 1, 20));
    expect(q.vehicle, VehicleKind.truck);
    expect(q.vehicles.where((v) => v.suggested).single.kind, VehicleKind.truck);
    expect(q.lines.helperCount, 3);
    // Thu 1 Oct → Wed 7 Oct: Saturday and Sunday cost 10 % more.
    expect(q.days, hasLength(7));
    expect([for (final d in q.days) d.weekend], [false, false, true, true, false, false, false]);
    // A weekday's total is its subtotal; Saturday adds 10 % of it.
    expect(q.days[2].total, q.days[0].total + q.days[0].total * 10 ~/ 100);
  });

  test('details go to the API with typed items, and come back with their lines', () {
    const d = ShiftingDetails(
      homeSize: HomeSize.oneBhk,
      items: [ShiftingItem(name: ' Double cot ', note: 'comes apart'), ShiftingItem(name: 'Cartons', qty: 12)],
      pickupFloor: 2,
      packing: PackingLevel.basic,
    );
    final json = d.toJson();
    expect(json['items'], [
      {'name': 'Double cot', 'qty': 1, 'note': 'comes apart'},
      {'name': 'Cartons', 'qty': 12},
    ]);
    expect(d.toJson(withItems: false).containsKey('items'), isFalse);
    expect(json['homeSize'], 'ONE_BHK');
    expect(json['packing'], 'BASIC');
    final back = ShiftingDetails.fromJson({...json, 'lines': GoodsModeRates.lines(d, 1236, DateTime.utc(2026, 10, 1, 3, 30)).toJson()})!;
    expect(back.itemCount, 13);
    expect(back.lines!.total, 3135);
    expect(floorLabel(0, false), 'Ground floor');
    expect(floorLabel(2, false), '2nd floor · no lift');
    expect(floorLabel(11, true), '11th floor · lift');
    expect(floorLabel(23, true), '23rd floor · lift');
  });
}
