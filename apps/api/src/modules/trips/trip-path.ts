import { haversineMeters } from '../fares/fare-engine.js';

/**
 * A trip's recorded GPS path (breadcrumbs) and what is measured from it: the actual distance driven, a small
 * encoded polyline for admins, and whether the recording is good enough to trust (like Namma Yatri's
 * location-updates / EndRide checks). Pure functions; Redis storage is in `TripTrackService`.
 */

/** Which part of the trip a point belongs to: driving to the pickup, or the ride / delivery itself. */
export type PathPhase = 'p' | 't';

export interface PathPoint {
  readonly ts: number;
  readonly lat: number;
  readonly lng: number;
  readonly acc: number | null;
  readonly mock: boolean;
  readonly phase: PathPhase;
}

/** Fixes less accurate than this are not recorded (Namma Yatri drops acc ≥ 50 m for billing). */
export const MAX_POINT_ACCURACY_M = 50;
/** A point implying a faster move than this from the last kept point is a GPS jump. */
export const MAX_PATH_SPEED_KMH = 120;
/** Kept points this far apart mean the recording has a hole: the distance is not trusted. */
export const MAX_PATH_GAP_M = 2000;
/** After this many jumps in a row the path re-anchors on the new position (the earlier anchor was the bad one). */
const JUMPS_BEFORE_REANCHOR = 3;
/** Douglas–Peucker tolerance for the stored polyline. */
export const SIMPLIFY_TOLERANCE_M = 10;

/** `ts,lat,lng,acc,mock,phase` as stored in the Redis list. */
export function encodePoint(p: PathPoint): string {
  return `${p.ts},${p.lat.toFixed(6)},${p.lng.toFixed(6)},${p.acc === null ? '' : Math.round(p.acc)},${p.mock ? 1 : 0},${p.phase}`;
}

export function decodePoint(raw: string): PathPoint | null {
  const [ts, lat, lng, acc, mock, phase] = raw.split(',');
  const p = { ts: Number(ts), lat: Number(lat), lng: Number(lng) };
  if (![p.ts, p.lat, p.lng].every(Number.isFinite) || (phase !== 'p' && phase !== 't')) return null;
  return { ...p, acc: acc === '' || acc === undefined ? null : Number(acc), mock: mock === '1', phase };
}

/** Whether a fix is precise enough to record (no accuracy sent = old app: kept). */
export function isAccurateEnough(acc: number | null, maxAccuracyM = MAX_POINT_ACCURACY_M): boolean {
  return acc === null || acc <= maxAccuracyM;
}

/**
 * The points worth measuring, in time order: exact duplicates (same time, or same place as the last kept point) and
 * GPS jumps (faster than [maxSpeedKmh] from the last kept point) are dropped. After a few jumps in a row the newest
 * becomes the anchor, so one bad first point can't discard the rest of the trip.
 */
export function filterPath(points: readonly PathPoint[], maxSpeedKmh = MAX_PATH_SPEED_KMH): PathPoint[] {
  const sorted = [...points].sort((a, b) => a.ts - b.ts);
  const kept: PathPoint[] = [];
  let jumps = 0;
  for (const p of sorted) {
    const last = kept[kept.length - 1];
    if (!last) {
      kept.push(p);
      continue;
    }
    // Standing still at the pickup: the first ride point is kept even at the approach's last position.
    if (p.ts === last.ts || (p.lat === last.lat && p.lng === last.lng && p.phase === last.phase)) continue;
    const metres = haversineMeters(last, p);
    const kmh = (metres / ((p.ts - last.ts) / 1000)) * 3.6;
    if (kmh > maxSpeedKmh) {
      jumps++;
      if (jumps < JUMPS_BEFORE_REANCHOR) continue;
    }
    jumps = 0;
    kept.push(p);
  }
  return kept;
}

/** Sum of straight lines between consecutive points (metres), and the longest single step. */
export function pathLength(points: readonly { lat: number; lng: number }[]): { metres: number; longestStepM: number } {
  let metres = 0;
  let longestStepM = 0;
  for (let i = 1; i < points.length; i++) {
    const step = haversineMeters(points[i - 1], points[i]);
    metres += step;
    longestStepM = Math.max(longestStepM, step);
  }
  return { metres, longestStepM };
}

/** Douglas–Peucker on a local flat projection (fine at city scale). Keeps the first and last point. */
export function simplifyPath<T extends { lat: number; lng: number }>(points: readonly T[], toleranceM = SIMPLIFY_TOLERANCE_M): T[] {
  if (points.length <= 2) return [...points];
  const lat0 = (points[0].lat * Math.PI) / 180;
  const mPerDeg = 111_320;
  const xy = points.map((p) => ({ x: p.lng * mPerDeg * Math.cos(lat0), y: p.lat * mPerDeg }));
  const keep = new Uint8Array(points.length);
  keep[0] = 1;
  keep[points.length - 1] = 1;
  const stack: [number, number][] = [[0, points.length - 1]];
  while (stack.length) {
    const [from, to] = stack.pop()!;
    const a = xy[from];
    const b = xy[to];
    const dx = b.x - a.x;
    const dy = b.y - a.y;
    const len2 = dx * dx + dy * dy;
    let worst = -1;
    let worstD = 0;
    for (let i = from + 1; i < to; i++) {
      const p = xy[i];
      const t = len2 === 0 ? 0 : Math.max(0, Math.min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / len2));
      const d = Math.hypot(p.x - (a.x + t * dx), p.y - (a.y + t * dy));
      if (d > worstD) {
        worstD = d;
        worst = i;
      }
    }
    if (worst !== -1 && worstD > toleranceM) {
      keep[worst] = 1;
      stack.push([from, worst], [worst, to]);
    }
  }
  return points.filter((_, i) => keep[i] === 1);
}

/** Google's encoded polyline format (precision 5), which the admin map and the apps' codecs decode. */
export function encodePolyline(points: readonly { lat: number; lng: number }[]): string {
  let out = '';
  let prevLat = 0;
  let prevLng = 0;
  const encode = (v: number): void => {
    let n = v < 0 ? ~(v << 1) : v << 1;
    while (n >= 0x20) {
      out += String.fromCharCode((0x20 | (n & 0x1f)) + 63);
      n >>= 5;
    }
    out += String.fromCharCode(n + 63);
  };
  for (const p of points) {
    const lat = Math.round(p.lat * 1e5);
    const lng = Math.round(p.lng * 1e5);
    encode(lat - prevLat);
    encode(lng - prevLng);
    prevLat = lat;
    prevLng = lng;
  }
  return out;
}

/** What is stored on the trip at completion. */
export interface PathSummary {
  /** Metres driven during the ride / delivery (null when [distanceCalcFailed]). */
  readonly actualDistanceM: number | null;
  /** Metres driven to the pickup (null with fewer than 2 points there). */
  readonly approachDistanceM: number | null;
  /** The ride's path, simplified and encoded (null with fewer than 2 points). */
  readonly pathPolyline: string | null;
  /** Points of the ride kept after filtering. */
  readonly gpsPoints: number;
  /** Mock-location fixes seen while on the trip. */
  readonly gpsMockCount: number;
  /** Too few points, or a hole longer than [MAX_PATH_GAP_M]: the distance can't be trusted. */
  readonly distanceCalcFailed: boolean;
}

/** Measures the recorded [points] of a trip (any order). [mockCount]: mock fixes counted while recording. */
export function summarizePath(points: readonly PathPoint[], mockCount: number, opts: { maxSpeedKmh?: number; maxGapM?: number } = {}): PathSummary {
  const kept = filterPath(points, opts.maxSpeedKmh);
  const ride = kept.filter((p) => p.phase === 't');
  const approach = kept.filter((p) => p.phase === 'p');
  const measured = pathLength(ride);
  const isFailed = ride.length < 2 || measured.longestStepM > (opts.maxGapM ?? MAX_PATH_GAP_M);
  return {
    actualDistanceM: isFailed ? null : Math.round(measured.metres),
    approachDistanceM: approach.length >= 2 ? Math.round(pathLength(approach).metres) : null,
    pathPolyline: ride.length >= 2 ? encodePolyline(simplifyPath(ride)) : null,
    gpsPoints: ride.length,
    gpsMockCount: mockCount,
    distanceCalcFailed: isFailed,
  };
}
