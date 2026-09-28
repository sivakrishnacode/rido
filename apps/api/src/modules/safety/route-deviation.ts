/** A deviation is this many fixes in a row off the route (Namma Yatri: 3 points, with road snapping). */
export const DEVIATION_FIXES = 3;
/** At night, a deviation this far off the route asks the passenger "Is everything OK?". */
export const NIGHT_DEVIATION_PUSH_M = 1000;

type Point = { readonly lat: number; readonly lng: number };

const M_PER_DEG_LAT = 111_320;

/**
 * Shortest distance in metres from [p] to the polyline [path] (to its segments, not just its vertices). Flat-earth
 * projection around [p]: exact enough within a city. Infinity for an empty path.
 */
export function distanceToPathM(p: Point, path: readonly Point[]): number {
  if (path.length === 0) return Infinity;
  const kx = M_PER_DEG_LAT * Math.cos((p.lat * Math.PI) / 180);
  const xy = (q: Point) => ({ x: (q.lng - p.lng) * kx, y: (q.lat - p.lat) * M_PER_DEG_LAT });
  let best = Infinity;
  let a = xy(path[0]);
  if (path.length === 1) return Math.hypot(a.x, a.y);
  for (let i = 1; i < path.length; i++) {
    const b = xy(path[i]);
    const dx = b.x - a.x;
    const dy = b.y - a.y;
    const len2 = dx * dx + dy * dy;
    // Projection of the origin (p) onto segment a→b, clamped to the segment.
    const t = len2 === 0 ? 0 : Math.max(0, Math.min(1, -(a.x * dx + a.y * dy) / len2));
    best = Math.min(best, Math.hypot(a.x + t * dx, a.y + t * dy));
    a = b;
  }
  return best;
}

export interface DeviationStep {
  /** Consecutive fixes off the route so far (0 once back on it). */
  readonly count: number;
  readonly offM: number;
  /** [DEVIATION_FIXES] or more in a row: the caller records it (deduped). */
  readonly isDeviation: boolean;
}

/** One fix through the deviation counter: more than [thresholdM] (setting `deviationM`) off [path] counts. */
export function stepDeviation(count: number, fix: Point, path: readonly Point[], thresholdM: number): DeviationStep {
  const offM = Math.round(distanceToPathM(fix, path));
  const next = offM > thresholdM ? count + 1 : 0;
  return { count: next, offM, isDeviation: next >= DEVIATION_FIXES };
}
