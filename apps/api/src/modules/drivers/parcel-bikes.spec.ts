import { TripKind, VehicleKind } from '../../generated/prisma/enums.js';
import { driverKindsFor, tripVehicleFor } from './parcel-bikes.js';

describe('parcel on bike', () => {
  it('bike drivers are searched for goods-bike parcels, never the other way round', () => {
    expect(driverKindsFor(VehicleKind.GOODS_BIKE)).toEqual([VehicleKind.GOODS_BIKE, VehicleKind.BIKE]);
    expect(driverKindsFor(VehicleKind.BIKE)).toEqual([VehicleKind.BIKE]);
    expect(driverKindsFor(VehicleKind.THREE_WHEELER)).toEqual([VehicleKind.THREE_WHEELER]);
  });

  it('a bike driver takes a parcel as a goods bike, a ride as a bike', () => {
    expect(tripVehicleFor(VehicleKind.BIKE, TripKind.PARCEL)).toBe(VehicleKind.GOODS_BIKE);
    expect(tripVehicleFor(VehicleKind.BIKE, TripKind.RIDE)).toBe(VehicleKind.BIKE);
    expect(tripVehicleFor(VehicleKind.AUTO, TripKind.RIDE)).toBe(VehicleKind.AUTO);
  });
});
