import type { PathSummary } from './trip-path.js';

/** The actual distance may differ from the quote by this much before it matters (Namma Yatri: 1.2 km)… */
export const DISTANCE_DIFF_MIN_M = 1200;
/** …or by this share of the quoted distance, whichever is more. */
export const DISTANCE_DIFF_SHARE = 0.25;

/**
 * Why a completed trip should be looked at by an admin (empty = fine). Fares always stay the quote; this only
 * flags: (a) mock-location fixes during the trip, (b) the recorded distance differs from the quote by more than
 * max(1.2 km, 25 %) while the driver marked Arrived or ended outside the stop's radius, (c) the distance couldn't be
 * measured from GPS.
 */
export function fareReviewNotes(p: {
  path: Pick<PathSummary, 'actualDistanceM' | 'gpsMockCount' | 'gpsPoints' | 'distanceCalcFailed'>;
  quotedKm: number;
  /** Driver was outside the arrival radius at "Arrived" (gave a reason). */
  isPickupFar: boolean;
  /** Driver was outside the drop radius at the end (gave a reason). */
  isDropFar: boolean;
}): string[] {
  const notes: string[] = [];
  const { path } = p;
  if (path.gpsMockCount > 0) notes.push(`Mock GPS: ${path.gpsMockCount} fix${path.gpsMockCount === 1 ? '' : 'es'} from a fake-location app`);
  if (path.distanceCalcFailed) {
    notes.push(`GPS distance not measured (${path.gpsPoints} point${path.gpsPoints === 1 ? '' : 's'} or a gap over 2 km)`);
  } else if (path.actualDistanceM !== null && (p.isPickupFar || p.isDropFar)) {
    const quotedM = p.quotedKm * 1000;
    const diffM = Math.abs(path.actualDistanceM - quotedM);
    if (diffM > Math.max(DISTANCE_DIFF_MIN_M, DISTANCE_DIFF_SHARE * quotedM)) {
      const where = [p.isPickupFar && 'arrived away from the pickup', p.isDropFar && 'ended away from the drop'].filter(Boolean).join(' and ');
      notes.push(`Drove ${(path.actualDistanceM / 1000).toFixed(1)} km vs ${p.quotedKm.toFixed(1)} km quoted, and ${where}`);
    }
  }
  return notes;
}

/** [existing] review note plus [notes] (a stuck-trip note is kept). */
export function mergeReviewNote(existing: string | null, notes: readonly string[]): string | null {
  const all = [existing, ...notes].filter((n): n is string => !!n && n.trim().length > 0);
  return all.length ? all.join('; ') : null;
}
