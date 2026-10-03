import { VehicleKind } from '../../generated/prisma/enums.js';
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
/** Most helpers a mover can say they bring (a 3 BHK's 4 plus 4 extra). */
export const MAX_HELPERS = 8;
/** Helpers assumed when a driver switches house shifting on without saying how many. */
export const DEFAULT_HELPERS = 2;

/** Services a driver switches on or off, or pauses for a while (Services in the driver app). The vehicle's main
 *  service (rides; parcels for goods vehicles) is always on. */
export const SERVICE_KEYS = ['parcels', 'rentals', 'outstation', 'shifting'] as const;
export type ServiceKey = (typeof SERVICE_KEYS)[number];
/** Longest timed pause (minutes); longer is "until I start it again". */
export const MAX_PAUSE_MINUTES = 24 * 60;

/** A paused service: off until [until] (ISO), or until the driver starts it again (null). [reason] is for us. */
export interface ServicePause {
  until: string | null;
  reason: string | null;
}

/**
 * The services a vehicle can switch on and off: parcels for bikes, scooters and autos (Parcel on Auto), rentals and
 * outstation for cabs, goods to another town (outstation) and Packers & Movers (shifting) for goods trucks.
 */
export function servicesFor(kind: VehicleKind): ServiceKey[] {
  switch (kind) {
    case VehicleKind.BIKE:
    case VehicleKind.SCOOTY:
    case VehicleKind.AUTO:
      return ['parcels'];
    case VehicleKind.CAB:
    case VehicleKind.SEDAN:
    case VehicleKind.SUV:
      return ['rentals', 'outstation'];
    case VehicleKind.THREE_WHEELER:
    case VehicleKind.MINI_TRUCK:
    case VehicleKind.PICKUP:
    case VehicleKind.TRUCK:
      return ['outstation', 'shifting'];
    default:
      return [];
  }
}

/**
 * Whether [key] is on for a driver with [prefs] (read with readPrefs: a pause still in it is running). Unset, parcels
 * are on for two-wheelers and off for autos (their passenger seat), rentals and outstation on, shifting off.
 */
export function serviceOn(prefs: BookingPrefs | undefined, key: ServiceKey, driverKind?: VehicleKind): boolean {
  if (prefs?.pauses?.[key]) return false;
  switch (key) {
    case 'parcels':
      return prefs?.parcels ?? driverKind !== VehicleKind.AUTO;
    case 'rentals':
      return prefs?.rentals ?? true;
    case 'outstation':
      return prefs?.outstation ?? true;
    case 'shifting':
      return !!prefs?.shifting;
  }
}

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
 * Services ([serviceOn]): [parcels] a bike, scooter or auto also takes parcels (unset: the vehicle's default),
 * [rentals] / [outstation] (unset: on), [shifting] a goods-truck driver takes house shifting jobs (off by default:
 * they need helpers), bringing up to [helpers] helpers; [pauses] the services paused for now. [areas]: saved places.
 * Null / absent filters = no filter.
 */
export interface BookingPrefs {
  maxPickupKm?: number | null;
  minTripKm?: number | null;
  maxTripKm?: number | null;
  goTo?: GoTo | null;
  stayIn?: StayIn | null;
  parcels?: boolean;
  rentals?: boolean;
  outstation?: boolean;
  areas?: Area[];
  shifting?: boolean;
  helpers?: number;
  pauses?: Partial<Record<ServiceKey, ServicePause>>;
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

/** The pauses still running at [now] (a timed one that ended is dropped: the service is back on). */
function runningPauses(v: unknown, now: Date): Partial<Record<ServiceKey, ServicePause>> {
  if (!isObj(v)) return {};
  const out: Partial<Record<ServiceKey, ServicePause>> = {};
  for (const key of SERVICE_KEYS) {
    const p = v[key];
    if (!isObj(p)) continue;
    const until = typeof p.until === 'string' ? p.until : null;
    if (until !== null && !(new Date(until) > now)) continue;
    out[key] = { until, reason: typeof p.reason === 'string' ? p.reason : null };
  }
  return out;
}

const flag = (v: unknown): boolean | undefined => (typeof v === 'boolean' ? v : undefined);

/** Stored JSON → prefs, ignoring anything malformed, an expired go-to / stay-in and pauses that ended. */
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
    parcels: flag(raw.parcels),
    rentals: flag(raw.rentals),
    outstation: flag(raw.outstation),
    areas: areas.slice(0, MAX_AREAS),
    shifting: raw.shifting === true,
    helpers:
      typeof raw.helpers === 'number' && Number.isInteger(raw.helpers) && raw.helpers >= 0 && raw.helpers <= MAX_HELPERS
        ? raw.helpers
        : DEFAULT_HELPERS,
    pauses: runningPauses(raw.pauses, now),
  };
}

/** Whether a mover with [prefs] (none saved: no) can take a house shift needing [helpers] helpers. */
export function takesShift(prefs: BookingPrefs | undefined, helpers: number): boolean {
  return serviceOn(prefs, 'shifting') && (prefs?.helpers ?? DEFAULT_HELPERS) >= helpers;
}

/** The helpers a trip's house shift needs (its price lines), or null when it isn't a shift. */
export function shiftHelpersOf(trip: { shifting?: unknown }): number | null {
  const s = trip.shifting;
  if (!s || typeof s !== 'object') return null;
  const lines = (s as { lines?: { helperCount?: unknown } }).lines;
  return typeof lines?.helperCount === 'number' ? lines.helperCount : 0;
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
