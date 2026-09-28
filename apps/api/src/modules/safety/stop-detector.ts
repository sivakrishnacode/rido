import { haversineMeters } from '../fares/fare-engine.js';

/** A stop only counts this far from both the pickup and the drop (waiting there is normal). */
export const STOP_AWAY_FROM_ENDS_M = 300;

type Point = { readonly lat: number; readonly lng: number };

/** Where the vehicle has been staying since [t] (epoch ms). Kept per trip in Redis. */
export interface StopAnchor extends Point {
  readonly t: number;
}

export interface StopConfig {
  /** Moving less than this from the anchor counts as standing still (setting `stopRadiusM`, default 30). */
  readonly radiusM: number;
  /** Standing still this long is a stop (setting `stopMinutes`, default 4). */
  readonly minutes: number;
}

export interface StopStep {
  /** The anchor to keep for the next fix. */
  readonly anchor: StopAnchor;
  /** How long the vehicle has stood at the anchor (ms). */
  readonly stoppedMs: number;
  /** Stood still at least `minutes`, away from pickup and drop. The caller dedupes the alert. */
  readonly isStop: boolean;
}

/**
 * One GPS fix through the stop detector (like Namma Yatri's StopDetection, cheap enough to run on every fix): a fix
 * farther than `radiusM` from the anchor moves the anchor there; otherwise the vehicle is still standing at it, and
 * after `minutes` that is a stop, unless the anchor is within [STOP_AWAY_FROM_ENDS_M] of the pickup or the drop. A fix
 * older than the anchor (a late batch) never moves it back.
 */
export function stepStop(anchor: StopAnchor | null, fix: Point & { readonly ts: number }, ends: { pickup: Point; drop: Point }, cfg: StopConfig): StopStep {
  if (!anchor || haversineMeters(anchor, fix) > cfg.radiusM) {
    const next = anchor && fix.ts < anchor.t ? anchor : { lat: fix.lat, lng: fix.lng, t: fix.ts };
    return { anchor: next, stoppedMs: 0, isStop: false };
  }
  const stoppedMs = Math.max(0, fix.ts - anchor.t);
  const isAway = haversineMeters(anchor, ends.pickup) > STOP_AWAY_FROM_ENDS_M && haversineMeters(anchor, ends.drop) > STOP_AWAY_FROM_ENDS_M;
  return { anchor, stoppedMs, isStop: isAway && stoppedMs >= cfg.minutes * 60_000 };
}
