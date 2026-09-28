import { readFileSync } from 'node:fs';

import type { VehicleKind } from '../../generated/prisma/enums.js';
import { estimateRoute, quoteFare } from './fare-engine.js';

/** Shared with the Dart engine's test, so the two engines can't drift apart. */
interface FareCase {
  readonly name: string;
  readonly input: { vehicleKind: VehicleKind; distanceKm: number; durationMin: number; multiplier: number; maxMultiplier?: number };
  readonly expected: Record<string, number>;
}
const FARE_CASES = (
  JSON.parse(readFileSync(new URL('../../../../../packages/rido_data/test/fixtures/fare_cases.json', import.meta.url), 'utf8')) as {
    cases: FareCase[];
  }
).cases;

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

  it('adds no peak markup by default', () => {
    const route = estimateRoute(gandhipuram, brookefields);
    const quotes = (['BIKE', 'AUTO', 'CAB'] as const).map((k) => quoteFare({ vehicleKind: k, route }));
    expect(quotes.map((q) => q.total)).toEqual([35, 66, 132]);
    expect(quotes.every((q) => q.multiplier === 1 && q.peakCharge === 0)).toBe(true);
  });

  it('matches the ride fares in the designs (peak 1.1x)', () => {
    const route = estimateRoute(gandhipuram, brookefields);
    const totals = (['BIKE', 'AUTO', 'CAB'] as const).map((k) => quoteFare({ vehicleKind: k, route, multiplier: 1.1 }).total);
    expect(totals).toEqual([38, 72, 145]);
  });

  it('matches the goods fares in the designs (peak 1.1x)', () => {
    const route = estimateRoute(peelamedu, raceCourse);
    const totals = (['GOODS_BIKE', 'THREE_WHEELER', 'MINI_TRUCK'] as const).map(
      (k) => quoteFare({ vehicleKind: k, route, multiplier: 1.1 }).total,
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

  it('caps the multiplier at the admin maxMultiplier', () => {
    const route = estimateRoute(gandhipuram, raceCourse);
    expect(quoteFare({ vehicleKind: 'CAB', route, multiplier: 1.4, maxMultiplier: 1.2 }).multiplier).toBe(1.2);
    expect(quoteFare({ vehicleKind: 'CAB', route, multiplier: 1.4, maxMultiplier: 0.5 }).multiplier).toBe(1);
  });

  it('applies the multiplier before the minimum fare, never to the top-up', () => {
    // Bike 0.5 km / 1 min: 12 + 2 + 0 = 14, × 1.5 = 21, topped up to the ₹25 minimum (not 25 × 1.5).
    const q = quoteFare({ vehicleKind: 'BIKE', route: { distanceKm: 0.5, durationMin: 1 }, multiplier: 1.5 });
    expect(q).toMatchObject({ subtotal: 18, minFareTopUp: 4, peakCharge: 7, total: 25 });
    // Surge that already clears the minimum needs no top-up: 12 + 10 + 0 = 22 × 1.5 = 33.
    const big = quoteFare({ vehicleKind: 'BIKE', route: { distanceKm: 2, durationMin: 1 }, multiplier: 1.5 });
    expect(big).toMatchObject({ minFareTopUp: 0, subtotal: 22, peakCharge: 11, total: 33 });
  });

  it('has the shared fixture cases', () => expect(FARE_CASES.length).toBeGreaterThanOrEqual(10));

  it.each(FARE_CASES)('shared case: $name', ({ input, expected }) => {
    const q = quoteFare({
      vehicleKind: input.vehicleKind,
      route: { distanceKm: input.distanceKm, durationMin: input.durationMin },
      multiplier: input.multiplier,
      maxMultiplier: input.maxMultiplier,
    });
    expect(q).toMatchObject(expected);
  });
});
