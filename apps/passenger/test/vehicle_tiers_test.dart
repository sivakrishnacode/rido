// P-10 lists every ride tier (Bike, Scooty, Auto, Auto Priority, Mini, Sedan, SUV) with its picture and the demo
// fares, the same numbers the API quotes for the demo route.
import 'package:flutter_test/flutter_test.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';
import 'package:tamiltaxi_passenger/router/routes.dart';
import 'package:tamiltaxi_ui/tamiltaxi_ui.dart';

import 'support/harness.dart';

void main() {
  testWidgets('P-10 shows the seven ride tiers with their pictures and fares', (tester) async {
    await pumpRoute(tester, Routes.chooseVehicle);
    await tester.pump(const Duration(seconds: 1));

    const tiers = {'Bike': 35, 'Scooty': 39, 'Auto': 66, 'Auto Priority': 80, 'Mini': 132, 'Sedan': 158, 'SUV': 210};
    for (final MapEntry(key: name, value: fare) in tiers.entries) {
      expect(find.text(name, skipOffstage: false), findsWidgets, reason: name);
      expect(find.text(formatInr(fare), skipOffstage: false), findsWidgets, reason: '$name $fare');
    }
    expect(find.byType(VehicleArt, skipOffstage: false), findsNWidgets(7));
    expect(Seed.rideVehicles.map((v) => v.kind), [
      VehicleKind.bike,
      VehicleKind.scooty,
      VehicleKind.auto,
      VehicleKind.autoPriority,
      VehicleKind.cab,
      VehicleKind.sedan,
      VehicleKind.suv,
    ]);
  });

  test('every ride tier has a render; Auto Priority is not a driver vehicle', () {
    for (final v in Seed.rideVehicles) {
      expect(v.kind.artAsset, isNotNull, reason: v.name);
    }
    expect(VehicleKind.autoPriority.isDriverVehicle, isFalse);
    expect(VehicleKind.scooty.isTwoWheeler, isTrue);
    expect(VehicleKind.suv.isRide, isTrue);
    expect(VehicleKind.goodsBike.isGoods, isTrue);
  });
}
