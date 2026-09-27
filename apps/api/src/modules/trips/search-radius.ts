/** Settings that shape how far and how long a booking searches (settings.defaults.ts). */
export interface SearchSettings {
  readonly searchRadiusKm: number;
  readonly maxSearchRadiusKm: number;
  readonly searchExpandSeconds: number;
}

/** Keep searching this long when some driver was offered the trip, or when nobody was found at all. */
const SEARCH_FOR_MS = 90_000;
const SEARCH_EMPTY_FOR_MS = 30_000;
/** After the radius reaches its maximum, keep looking this long before "No drivers". */
const AT_MAX_RADIUS_MS = 15_000;

/**
 * Search radius [ageMs] into a booking's search: [SearchSettings.searchRadiusKm] at first, widening linearly to
 * [SearchSettings.maxSearchRadiusKm] over [SearchSettings.searchExpandSeconds] (few drivers early on: a driver 10 km
 * away beats "No drivers"). Rounded to 0.1 km.
 */
export function searchRadiusAt(ageMs: number, s: SearchSettings): number {
  const start = s.searchRadiusKm;
  const max = Math.max(start, s.maxSearchRadiusKm);
  const expandMs = s.searchExpandSeconds * 1000;
  const t = expandMs <= 0 ? 1 : Math.min(1, Math.max(0, ageMs / expandMs));
  return Math.round((start + (max - start) * t) * 10) / 10;
}

/** How long a booking may search before "No drivers": long enough for the radius to widen fully. */
export function searchWindowMs(wasOffered: boolean, s: SearchSettings): number {
  const widen = s.searchExpandSeconds * 1000 + AT_MAX_RADIUS_MS;
  return Math.max(wasOffered ? SEARCH_FOR_MS : SEARCH_EMPTY_FOR_MS, widen);
}
