import { estimateRoute, quoteFare } from './fare-engine.js';

const gandhipuram = { lat: 11.0183, lng: 76.9725, placeId: 'gandhipuram' };
const brookefields = { lat: 11.009, lng: 76.96, placeId: 'brookefields' };
const peelamedu = { lat: 11.029, lng: 77.027, placeId: 'peelamedu' };
const raceCourse = { lat: 10.999, lng: 76.978, placeId: 'race-course' };

describe('fare engine', () => {
  it('uses measured distances for the demo routes', () => {
    // Arrange / Act
    const route = estimateRoute(gandhipuram, brookefields);
    // Assert
    expect(route).toEqual({ distanceKm: 4.2, durationMin: 14 });
  });

  it('matches the ride fares in the designs', () => {
    const route = estimateRoute(gandhipuram, brookefields);
    const totals = (['BIKE', 'AUTO', 'CAB'] as const).map((k) => quoteFare({ vehicleKind: k, route }).total);
    expect(totals).toEqual([38, 72, 145]);
  });

  it('matches the goods fares in the designs', () => {
    const route = estimateRoute(peelamedu, raceCourse);
    const totals = (['GOODS_BIKE', 'THREE_WHEELER', 'MINI_TRUCK'] as const).map(
      (k) => quoteFare({ vehicleKind: k, route }).total,
    );
    expect(totals).toEqual([49, 180, 420]);
  });

  it('adds up exactly and caps the multiplier at 1.5x', () => {
    const route = estimateRoute(gandhipuram, raceCourse);
    const q = quoteFare({ vehicleKind: 'CAB', route, multiplier: 3 });
    expect(q.multiplier).toBe(1.5);
    expect(q.base + q.distanceCharge + q.timeCharge + q.minFareTopUp).toBe(q.subtotal);
    expect(q.subtotal + q.peakCharge).toBe(q.total);
  });
});
