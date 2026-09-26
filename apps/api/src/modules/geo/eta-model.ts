import { haversineMeters } from '../fares/fare-engine.js';

/** Straight line → road distance. */
export const ROAD_FACTOR = 1.3;
/** City approach speed when neither a learned speed nor a road ETA is available. */
export const FALLBACK_KMH = 20;

/** Estimated road km between two points. */
export function roadKm(from: { lat: number; lng: number }, to: { lat: number; lng: number }): number {
  return (haversineMeters(from, to) / 1000) * ROAD_FACTOR;
}

/** Minutes to cover [km] at [kmh], at least 1. */
export function etaMinutes(km: number, kmh: number): number {
  return Math.max(1, Math.round((km / kmh) * 60));
}
