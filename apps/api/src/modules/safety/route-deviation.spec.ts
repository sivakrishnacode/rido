import { encodePolyline } from '../trips/trip-path.js';
import { decodePolyline } from '../maps/polyline.js';
import { DEVIATION_FIXES, distanceToPathM, stepDeviation } from './route-deviation.js';

/** Gandhipuram → Brookefields along two legs (south, then west), as the stored (encoded) route. */
const ROUTE = decodePolyline(encodePolyline([
  { lat: 11.0183, lng: 76.9725 },
  { lat: 11.009, lng: 76.9725 },
  { lat: 11.009, lng: 76.96 },
]));
const east = (p: { lat: number; lng: number }, m: number) => ({ lat: p.lat, lng: p.lng + m / (111_320 * Math.cos((p.lat * Math.PI) / 180)) });

describe('distanceToPathM', () => {
  it('measures to the nearest segment, not just the vertices', () => {
    // Halfway down the first leg, 200 m east of it.
    expect(distanceToPathM(east({ lat: 11.0136, lng: 76.9725 }, 200), ROUTE)).toBeCloseTo(200, -1);
    // On the route.
    expect(distanceToPathM({ lat: 11.009, lng: 76.965 }, ROUTE)).toBeLessThan(2);
    expect(distanceToPathM({ lat: 11, lng: 77 }, [])).toBe(Infinity);
  });
});

describe('stepDeviation', () => {
  it('flags 3 fixes in a row more than 150 m off the route', () => {
    let count = 0;
    const flags: boolean[] = [];
    for (const lat of [11.017, 11.016, 11.015, 11.014]) {
      const step = stepDeviation(count, east({ lat, lng: 76.9725 }, 400), ROUTE, 150);
      count = step.count;
      flags.push(step.isDeviation);
      expect(step.offM).toBeGreaterThan(390);
    }
    expect(flags).toEqual([false, false, true, true]);
    expect(DEVIATION_FIXES).toBe(3);
  });

  it('a fix back on the route resets the count; small drift is not a deviation', () => {
    let s = stepDeviation(0, east({ lat: 11.017, lng: 76.9725 }, 400), ROUTE, 150);
    s = stepDeviation(s.count, east({ lat: 11.016, lng: 76.9725 }, 400), ROUTE, 150);
    s = stepDeviation(s.count, { lat: 11.015, lng: 76.9726 }, ROUTE, 150);
    expect(s).toMatchObject({ count: 0, isDeviation: false });
    for (let i = 0; i < 5; i++) s = stepDeviation(s.count, east({ lat: 11.014, lng: 76.9725 }, 120), ROUTE, 150);
    expect(s.isDeviation).toBe(false);
  });
});
