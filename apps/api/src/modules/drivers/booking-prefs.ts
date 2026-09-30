import { haversineMeters } from '../fares/fare-engine.js';

/** How long a go-to destination stays on once set (then requests are unfiltered again). */
export const GO_TO_HOURS = 2;
/** A trip counts as heading home when its drop is this close to the go-to destination… */
export const GO_TO_NEAR_KM = 3;
/** …or leaves the driver at most this share of today's distance to it. */
export const GO_TO_SHARE = 0.5;
/** How long a stay-in area stays on once set (a working day). */
export const STAY_IN_HOURS = 12;
/** Saved areas a driver can keep for Go To / Stay In. */
export const MAX_AREAS = 6;

/** A place the driver saved ("Home", "RS Puram stand") to switch Go To or Stay In on with one tap. */
export interface Area {
  name: string;
  lat: number;
  lng: number;
}

export interface GoTo extends Area {
  /** ISO time the go-to switches itself off. */
  until: string;
}

/** Stay In: only trips that start and end within [radiusKm] of the area. */
export interface StayIn extends Area {
  radiusKm: number;
  /** ISO time the stay-in switches itself off. */
  until: string;
}

/**
 * The driver's booking preferences (Driver.bookingPrefs), like Namma Yatri's and Rapido's: only trips whose pickup is
 * within [maxPickupKm] (straight line), whose length is within [minTripKm]…[maxTripKm], while [goTo] is on whose drop
 * takes the driver towards it, and while [stayIn] is on that start and end inside it (one of the two at a time).
 * [parcels]: a bike driver also gets goods-bike parcels (parcel-bikes.ts; default on). [areas]: the saved places.
 * Null / absent filters = no filter.
 */
export interface BookingPrefs {
  maxPickupKm?: number | null;
  minTripKm?: number | null;
  maxTripKm?: number | null;
  goTo?: GoTo | null;
  stayIn?: StayIn | null;
  parcels?: boolean;
  areas?: Area[];
}

type Raw = Record<string, unknown>;
const isObj = (v: unknown): v is Raw => !!v && typeof v === 'object' && !Array.isArray(v);
const area = (a: Raw): Area | null =>
  typeof a.lat === 'number' && typeof a.lng === 'number' ? { name: typeof a.name === 'string' ? a.name : '', lat: a.lat, lng: a.lng } : null;

/** A go-to / stay-in still running at [now], else null. */
function timed(v: unknown, now: Date): (Area & { until: string }) | null {
  if (!isObj(v) || typeof v.until !== 'string' || !(new Date(v.until) > now)) return null;
  const a = area(v);
  return a && { ...a, until: v.until };
}

/** Stored JSON → prefs, ignoring anything malformed and an expired go-to / stay-in. */
export function readPrefs(raw: unknown, now: Date): BookingPrefs {
  if (!isObj(raw)) return {};
  const num = (v: unknown): number | null => (typeof v === 'number' && Number.isFinite(v) && v > 0 ? v : null);
  const stayInOn = timed(raw.stayIn, now);
  const radiusKm = isObj(raw.stayIn) ? num(raw.stayIn.radiusKm) : null;
  const areas = (Array.isArray(raw.areas) ? raw.areas : []).filter(isObj).map(area).filter((a): a is Area => a !== null);
  return {
    maxPickupKm: num(raw.maxPickupKm),
    minTripKm: num(raw.minTripKm),
    maxTripKm: num(raw.maxTripKm),
    goTo: timed(raw.goTo, now),
    stayIn: stayInOn && radiusKm ? { ...stayInOn, radiusKm } : null,
    parcels: raw.parcels !== false,
    areas: areas.slice(0, MAX_AREAS),
  };
}

/** Whether a trip fits a driver's preferences. [driver] is the driver's position and straight-line km to the pickup. */
export function fitsPrefs(
  prefs: BookingPrefs,
  driver: { lat: number; lng: number; distanceKm: number },
  trip: { distanceKm: number; pickupLat: number; pickupLng: number; dropLat: number; dropLng: number },
): boolean {
  if (prefs.maxPickupKm && driver.distanceKm > prefs.maxPickupKm) return false;
  if (prefs.minTripKm && trip.distanceKm < prefs.minTripKm) return false;
  if (prefs.maxTripKm && trip.distanceKm > prefs.maxTripKm) return false;
  const drop = { lat: trip.dropLat, lng: trip.dropLng };
  if (prefs.goTo) {
    const dropToHome = haversineMeters(drop, prefs.goTo) / 1000;
    const nowToHome = haversineMeters(driver, prefs.goTo) / 1000;
    if (dropToHome > GO_TO_NEAR_KM && dropToHome > nowToHome * GO_TO_SHARE) return false;
  }
  if (prefs.stayIn) {
    const km = (p: { lat: number; lng: number }): number => haversineMeters(p, prefs.stayIn!) / 1000;
    if (km({ lat: trip.pickupLat, lng: trip.pickupLng }) > prefs.stayIn.radiusKm || km(drop) > prefs.stayIn.radiusKm) return false;
  }
  return true;
}
