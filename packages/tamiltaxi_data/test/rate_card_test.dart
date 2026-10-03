import 'package:flutter_test/flutter_test.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';

void main() {
  test("RateCard reads the API's rate card; a vehicle it lacks keeps the built-in rates", () {
    final rc = RateCard.fromJson({
      'rules': {
        'AUTO': {'base': 30, 'perKm': 10, 'perMin': 0.5, 'minFare': 40, 'waitPerMin': 2},
        'AUTO_PARCEL': {'base': 28, 'perKm': 9.5, 'perMin': 0.3, 'minFare': 45, 'waitPerMin': 1},
      },
      'freeWaitMin': 5,
      'waitMaxCharge': 40,
      'maxMultiplier': 1.3,
      'cancellationFee': 15,
    });
    expect(rc.ruleFor(VehicleKind.auto).base, 30);
    expect(rc.ruleFor(VehicleKind.autoParcel).minFare, 45);
    expect(rc.ruleFor(VehicleKind.bike).base, Seed.bike.fareRule.base);
    expect((rc.freeWaitMin, rc.waitMaxCharge, rc.maxMultiplier, rc.cancellationFee), (5, 40, 1.3, 15));
    expect(RateCard.fromJson(const {}).cancellationFee, isNull, reason: 'the fee is off');
  });

  test('Parcel on Auto: up to 100 kg, served by autos and goods 3-wheelers, never a registered vehicle', () {
    expect(Seed.vehicle(VehicleKind.autoParcel).capacityKg, 100);
    expect(VehicleKind.autoParcel.isGoods, isTrue);
    expect(VehicleKind.autoParcel.servedBy, [VehicleKind.auto, VehicleKind.threeWheeler]);
    expect(VehicleKind.autoParcel.isDriverVehicle, isFalse);
  });
}
