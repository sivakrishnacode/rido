import type { VehicleKind } from '../../generated/prisma/enums.js';
import { FARE_RULES } from './fare-rules.js';

/** A point with an optional known-place id (used for measured demo routes). */
export interface GeoPoint {
  readonly lat: number;
  readonly lng: number;
  readonly placeId?: string;
}

export interface RouteEstimate {
  readonly distanceKm: number;
  readonly durationMin: number;
}

/**
 * Itemised quote; every line is a whole rupee and they add up exactly to [total]:
 * base + distanceCharge + timeCharge + minFareTopUp = subtotal, subtotal + peakCharge = total.
 */
export interface FareQuote extends RouteEstimate {
  readonly vehicleKind: VehicleKind;
  readonly base: number;
  readonly distanceCharge: number;
  readonly timeCharge: number;
  readonly minFareTopUp: number;
  readonly subtotal: number;
  readonly multiplier: number;
  readonly peakCharge: number;
  readonly total: number;
}

const ROAD_FACTOR = 1.3;
const AVERAGE_SPEED_KMH = 18;
/** Cap when the caller passes no `maxMultiplier` (the admin setting's default). */
export const MAX_MULTIPLIER = 1.5;
const EPS = 1e-9;
const EARTH_RADIUS_M = 6_371_000;

/** Measured distances for the demo routes (same as the apps). */
const KNOWN_ROUTES_KM: Readonly<Record<string, number>> = {
  'gandhipuram|brookefields': 4.2,
  'gandhipuram|brookefields-plaza': 4.4,
  'gandhipuram|brookebond-road': 4.0,
  'peelamedu|race-course': 6.8,
  'saibaba-colony|airport': 12.4,
  'rs-puram|junction': 3.6,
  'town-hall|ukkadam': 1.4,
  'psg-tech|tidel-park': 3.4,
};

/** Multiplier when the caller gives none: no peak markup (the live one comes from GeoService.locate). */
export const CURRENT_MULTIPLIER = 1.0;

function floorRupee(v: number): number {
  return Math.floor(v + EPS);
}

/** Great-circle distance in metres. */
export function haversineMeters(a: GeoPoint, b: GeoPoint): number {
  const rad = (d: number): number => (d * Math.PI) / 180;
  const dLat = rad(b.lat - a.lat);
  const dLng = rad(b.lng - a.lng);
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(rad(a.lat)) * Math.cos(rad(b.lat)) * Math.sin(dLng / 2) ** 2;
  return 2 * EARTH_RADIUS_M * Math.asin(Math.sqrt(h));
}

/** Road distance (haversine × 1.3, or a measured route) and duration at 18 km/h. */
export function estimateRoute(from: GeoPoint, to: GeoPoint): RouteEstimate {
  const known = KNOWN_ROUTES_KM[`${from.placeId}|${to.placeId}`] ?? KNOWN_ROUTES_KM[`${to.placeId}|${from.placeId}`];
  const km = known ?? Math.max(0.5, Math.round((haversineMeters(from, to) / 1000) * ROAD_FACTOR * 10) / 10);
  return { distanceKm: km, durationMin: Math.max(1, Math.round((km / AVERAGE_SPEED_KMH) * 60)) };
}

/**
 * Builds the itemised fare for one vehicle:
 * total = max(minFare, floor((base + perKm·km + perMin·min) × multiplier)), each line floored to the rupee.
 * The multiplier applies to the ride (base + distance + time) only, never to the minimum-fare top-up.
 */
export function quoteFare(params: {
  vehicleKind: VehicleKind;
  route: RouteEstimate;
  multiplier?: number;
  /** Cap for [multiplier] (admin `maxMultiplier` setting); defaults to [MAX_MULTIPLIER]. */
  maxMultiplier?: number;
  /** Per-city rates (admin panel); defaults to the built-in [FARE_RULES]. */
  rule?: { base: number; perKm: number; perMin: number; minFare: number };
}): FareQuote {
  const { vehicleKind, route } = params;
  const rule = params.rule ?? FARE_RULES[vehicleKind];
  const cap = Math.max(1, params.maxMultiplier ?? MAX_MULTIPLIER);
  const multiplier = Math.min(cap, Math.max(1, params.multiplier ?? CURRENT_MULTIPLIER));
  const distanceCharge = floorRupee(rule.perKm * route.distanceKm);
  const timeCharge = floorRupee(rule.perMin * route.durationMin);
  const raw = rule.base + distanceCharge + timeCharge;
  const surged = floorRupee(raw * multiplier);
  const minFareTopUp = Math.max(0, rule.minFare - surged);
  const subtotal = raw + minFareTopUp;
  const total = surged + minFareTopUp;
  return {
    vehicleKind,
    ...route,
    base: rule.base,
    distanceCharge,
    timeCharge,
    minFareTopUp,
    subtotal,
    multiplier,
    peakCharge: total - subtotal,
    total,
  };
}
