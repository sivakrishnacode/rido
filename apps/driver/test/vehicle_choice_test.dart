// D-04 / D-05: rides offer Bike, Scooty, Auto, Mini, Sedan and SUV (Auto Priority is a booking tier autos serve,
// never a vehicle to register).
import 'package:flutter_test/flutter_test.dart';
import 'package:tamiltaxi_driver/router/routes.dart';
import 'package:tamiltaxi_ui/tamiltaxi_ui.dart';

import 'support/harness.dart';

void main() {
  testWidgets('D-05 lists the six ride vehicles, not Auto Priority', (tester) async {
    await pumpRoute(tester, Routes.chooseVehicle);
    for (final name in ['Bike', 'Scooty', 'Auto', 'Mini', 'Sedan', 'SUV']) {
      expect(find.text(name, skipOffstage: false), findsOneWidget, reason: name);
    }
    expect(find.text('Auto Priority', skipOffstage: false), findsNothing);
    expect(find.byType(VehicleArt, skipOffstage: false), findsNWidgets(6));
  });

  testWidgets('D-04: two-wheelers once, under Rides with "+ Parcels"; Deliveries lists the goods vehicles', (tester) async {
    await pumpRoute(tester, Routes.workType);
    expect(find.byType(VehicleArt), findsNWidgets(10));
    expect(find.text('Bike'), findsOneWidget);
    expect(find.text('Scooty'), findsOneWidget);
    expect(find.text('+ Parcels'), findsNWidgets(2));
    expect(find.text('Mini truck'), findsOneWidget);
  });
}
