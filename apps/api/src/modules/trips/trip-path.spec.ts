import { haversineMeters } from '../fares/fare-engine.js';
import {
  decodePoint,
  encodePoint,
  encodePolyline,
  filterPath,
  isAccurateEnough,
  type PathPoint,
  pathLength,
  simplifyPath,
  summarizePath,
} from './trip-path.js';

const T0 = 1_800_000_000_000;
/** A point [northM] metres north of Gandhipuram at [s] seconds. */
function pt(s: number, northM: number, extra: Partial<PathPoint> = {}): PathPoint {
  return { ts: T0 + s * 1000, lat: 11.0183 + northM / 111_320, lng: 76.9725, acc: 5, mock: false, phase: 't', ...extra };
}

describe('breadcrumb points', () => {
  it('round-trip through the Redis string', () => {
    const p = pt(3, 100, { acc: null, mock: true, phase: 'p' });
    const back = decodePoint(encodePoint(p))!;
    expect(back).toMatchObject({ ts: p.ts, acc: null, mock: true, phase: 'p' });
    expect(back.lat).toBeCloseTo(p.lat, 6);
    expect(decodePoint('garbage')).toBeNull();
  });

  it('keep fixes up to 50 m accuracy (and old apps without one)', () => {
    expect(isAccurateEnough(12)).toBe(true);
    expect(isAccurateEnough(50)).toBe(true);
    expect(isAccurateEnough(51)).toBe(false);
    expect(isAccurateEnough(null)).toBe(true);
  });
});

describe('filterPath', () => {
  it('sorts by time and drops exact duplicates', () => {
    const kept = filterPath([pt(10, 100), pt(0, 0), pt(10, 100), pt(15, 100), pt(5, 50)]);
    expect(kept.map((p) => p.ts - T0)).toEqual([0, 5000, 10_000]);
  });

  it('drops a jump faster than 120 km/h from the last kept point', () => {
    // 5 s apart: 100 m = 72 km/h is fine, 1 km = 720 km/h is a jump.
    const kept = filterPath([pt(0, 0), pt(5, 100), pt(10, 1100), pt(15, 200)]);
    expect(kept.map((p) => p.ts - T0)).toEqual([0, 5000, 15_000]);
  });

  it('re-anchors after three jumps in a row (the first point was the bad one)', () => {
    const kept = filterPath([pt(0, 5000), pt(5, 0), pt(10, 50), pt(15, 100), pt(20, 150)]);
    expect(kept.map((p) => p.ts - T0)).toEqual([0, 15_000, 20_000]);
  });
});

describe('pathLength', () => {
  it('sums haversine steps and reports the longest', () => {
    const pts = [pt(0, 0), pt(10, 100), pt(20, 300)];
    const { metres, longestStepM } = pathLength(pts);
    expect(metres).toBeCloseTo(haversineMeters(pts[0], pts[2]), 3);
    expect(metres).toBeGreaterThan(299);
    expect(metres).toBeLessThan(301);
    expect(longestStepM).toBeCloseTo(200, 0);
  });
});

describe('simplifyPath + encodePolyline', () => {
  it('drops points within 10 m of the line and keeps corners', () => {
    const line = Array.from({ length: 20 }, (_, i) => ({ lat: 11 + i * 0.0001, lng: 76.97 + (i % 2) * 0.00002 }));
    expect(simplifyPath(line)).toEqual([line[0], line[19]]);
    const corner = [{ lat: 11, lng: 76.97 }, { lat: 11.001, lng: 76.97 }, { lat: 11.001, lng: 76.971 }];
    expect(simplifyPath(corner)).toHaveLength(3);
  });

  it("encodes Google's documented example", () => {
    expect(encodePolyline([{ lat: 38.5, lng: -120.2 }, { lat: 40.7, lng: -120.95 }, { lat: 43.252, lng: -126.453 }])).toBe('_p~iF~ps|U_ulLnnqC_mqNvxq`@');
    expect(encodePolyline([])).toBe('');
  });
});

describe('summarizePath', () => {
  it('measures the ride and the approach separately', () => {
    const approach = [pt(0, -400, { phase: 'p' }), pt(30, -200, { phase: 'p' }), pt(60, 0, { phase: 'p' })];
    const ride = Array.from({ length: 11 }, (_, i) => pt(100 + i * 10, i * 100));
    const s = summarizePath([...ride, ...approach], 0);
    expect(s.distanceCalcFailed).toBe(false);
    expect(s.actualDistanceM).toBeGreaterThanOrEqual(999);
    expect(s.actualDistanceM).toBeLessThanOrEqual(1001);
    expect(s.approachDistanceM).toBe(400);
    expect(s.gpsPoints).toBe(11);
    expect(s.pathPolyline).toBeTruthy();
  });

  it('fails with too few points or a hole of more than 2 km', () => {
    expect(summarizePath([pt(0, 0)], 0)).toMatchObject({ distanceCalcFailed: true, actualDistanceM: null, pathPolyline: null });
    // 2.5 km in 2 min (75 km/h, not a jump) with nothing in between.
    const hole = summarizePath([pt(0, 0), pt(10, 100), pt(130, 2600), pt(140, 2700)], 3);
    expect(hole).toMatchObject({ distanceCalcFailed: true, actualDistanceM: null, gpsMockCount: 3, gpsPoints: 4 });
  });
});
