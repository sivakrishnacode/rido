// D-04 / D-05: rides offer Bike, Scooty, Auto, Mini, Sedan and SUV (Auto Priority is a booking tier autos serve,
// never a vehicle to register).
import 'package:flutter_test/flutter_test.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';
import 'package:tamiltaxi_driver/features/onboarding/d05_choose_vehicle_screen.dart';
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
    // What each carries, not the commission line on every card.
    expect(find.text('1 passenger', skipOffstage: false), findsNWidgets(2));
    expect(find.text('3 passengers', skipOffstage: false), findsOneWidget);
    expect(find.text('0% commission', skipOffstage: false), findsNothing);
  });

  test('D-05 capacity: passengers for rides, kg or tonnes for goods', () {
    expect(capacityText(VehicleKind.bike), '1 passenger');
    expect(capacityText(VehicleKind.suv), '6 passengers');
    expect(capacityText(VehicleKind.threeWheeler), 'Up to 500 kg');
    expect(capacityText(VehicleKind.pickup), 'Up to 1.5 tonnes');
    expect(capacityText(VehicleKind.truck), 'Up to 4 tonnes');
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
