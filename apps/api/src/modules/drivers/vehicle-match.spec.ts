import { TripKind, VehicleKind } from '../../generated/prisma/enums.js';
import { DRIVER_VEHICLE_KINDS, driverKindsFor, isPriority, tripVehicleFor } from './vehicle-match.js';

describe('vehicle match', () => {
  it('bike and scooter drivers are searched for goods-bike parcels, never the other way round', () => {
    expect(driverKindsFor(VehicleKind.GOODS_BIKE)).toEqual([VehicleKind.GOODS_BIKE, VehicleKind.BIKE, VehicleKind.SCOOTY]);
    expect(driverKindsFor(VehicleKind.THREE_WHEELER)).toEqual([VehicleKind.THREE_WHEELER]);
  });

  it('scooters take Bike rides; bikes do not take Scooty rides', () => {
    expect(driverKindsFor(VehicleKind.BIKE)).toEqual([VehicleKind.BIKE, VehicleKind.SCOOTY]);
    expect(driverKindsFor(VehicleKind.SCOOTY)).toEqual([VehicleKind.SCOOTY]);
  });

  it('Auto Priority is served by autos and offered first; cab tiers only by their own cars', () => {
    expect(driverKindsFor(VehicleKind.AUTO_PRIORITY)).toEqual([VehicleKind.AUTO]);
    expect(isPriority(VehicleKind.AUTO_PRIORITY)).toBe(true);
    expect(isPriority(VehicleKind.AUTO)).toBe(false);
    expect(driverKindsFor(VehicleKind.CAB)).toEqual([VehicleKind.CAB]);
    expect(driverKindsFor(VehicleKind.SEDAN)).toEqual([VehicleKind.SEDAN]);
    expect(driverKindsFor(VehicleKind.SUV)).toEqual([VehicleKind.SUV]);
  });

  it('a bike or scooter driver takes a parcel as a goods bike, a ride as itself', () => {
    expect(tripVehicleFor(VehicleKind.BIKE, TripKind.PARCEL)).toBe(VehicleKind.GOODS_BIKE);
    expect(tripVehicleFor(VehicleKind.SCOOTY, TripKind.PARCEL)).toBe(VehicleKind.GOODS_BIKE);
    expect(tripVehicleFor(VehicleKind.BIKE, TripKind.RIDE)).toBe(VehicleKind.BIKE);
    expect(tripVehicleFor(VehicleKind.AUTO, TripKind.RIDE)).toBe(VehicleKind.AUTO);
  });

  it('Auto Priority is not a vehicle a driver registers with', () => {
    expect(DRIVER_VEHICLE_KINDS).not.toContain(VehicleKind.AUTO_PRIORITY);
    expect(DRIVER_VEHICLE_KINDS).toContain(VehicleKind.SCOOTY);
    expect(DRIVER_VEHICLE_KINDS).toContain(VehicleKind.SUV);
  });

  it('Parcel on Auto goes to autos and goods 3-wheelers; an auto takes a parcel as Parcel on Auto', () => {
    expect(driverKindsFor(VehicleKind.AUTO_PARCEL)).toEqual([VehicleKind.AUTO_PARCEL, VehicleKind.AUTO, VehicleKind.THREE_WHEELER]);
    expect(tripVehicleFor(VehicleKind.AUTO, TripKind.PARCEL)).toBe(VehicleKind.AUTO_PARCEL);
    expect(tripVehicleFor(VehicleKind.AUTO, TripKind.RIDE)).toBe(VehicleKind.AUTO);
    expect(DRIVER_VEHICLE_KINDS).not.toContain(VehicleKind.AUTO_PARCEL);
  });
});
