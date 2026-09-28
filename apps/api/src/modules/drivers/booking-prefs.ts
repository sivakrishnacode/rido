import { haversineMeters } from '../fares/fare-engine.js';

/** How long a go-to destination stays on once set (then requests are unfiltered again). */
export const GO_TO_HOURS = 2;
/** A trip counts as heading home when its drop is this close to the go-to destination… */
export const GO_TO_NEAR_KM = 3;
/** …or leaves the driver at most this share of today's distance to it. */
export const GO_TO_SHARE = 0.5;

export interface GoTo {
  lat: number;
  lng: number;
  name: string;
  /** ISO time the go-to switches itself off. */
  until: string;
}

/**
 * The driver's booking preferences (Driver.bookingPrefs), like Namma Yatri's: only trips whose pickup is within
 * [maxPickupKm] (straight line), whose length is within [minTripKm]…[maxTripKm], and, while [goTo] is on, whose drop
 * takes the driver towards it. Null / absent fields = no filter.
 */
export interface BookingPrefs {
  maxPickupKm?: number | null;
  minTripKm?: number | null;
  maxTripKm?: number | null;
  goTo?: GoTo | null;
}

/** Stored JSON → prefs, ignoring anything malformed and an expired go-to. */
export function readPrefs(raw: unknown, now: Date): BookingPrefs {
  if (!raw || typeof raw !== 'object') return {};
  const r = raw as Record<string, unknown>;
  const num = (v: unknown): number | null => (typeof v === 'number' && Number.isFinite(v) && v > 0 ? v : null);
  const g = r.goTo as Record<string, unknown> | null | undefined;
  const goTo =
    g && typeof g.lat === 'number' && typeof g.lng === 'number' && typeof g.until === 'string' && new Date(g.until) > now
      ? { lat: g.lat, lng: g.lng, name: typeof g.name === 'string' ? g.name : '', until: g.until }
      : null;
  return { maxPickupKm: num(r.maxPickupKm), minTripKm: num(r.minTripKm), maxTripKm: num(r.maxTripKm), goTo };
}

/** Whether a trip fits a driver's preferences. [driver] is the driver's position and straight-line km to the pickup. */
export function fitsPrefs(
  prefs: BookingPrefs,
  driver: { lat: number; lng: number; distanceKm: number },
  trip: { distanceKm: number; dropLat: number; dropLng: number },
): boolean {
  if (prefs.maxPickupKm && driver.distanceKm > prefs.maxPickupKm) return false;
  if (prefs.minTripKm && trip.distanceKm < prefs.minTripKm) return false;
  if (prefs.maxTripKm && trip.distanceKm > prefs.maxTripKm) return false;
  if (prefs.goTo) {
    const dropToHome = haversineMeters({ lat: trip.dropLat, lng: trip.dropLng }, prefs.goTo) / 1000;
    const nowToHome = haversineMeters(driver, prefs.goTo) / 1000;
    if (dropToHome > GO_TO_NEAR_KM && dropToHome > nowToHome * GO_TO_SHARE) return false;
  }
  return true;
}
