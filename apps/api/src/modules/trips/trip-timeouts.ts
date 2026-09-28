import type { Settings } from '../settings/settings.defaults.js';

/** Durable jobs per trip (JobsService), all keyed by the trip id. */
export const TRIP_JOBS = {
  /** DRIVER_ASSIGNED: has the driver got closer to the pickup since accepting? */
  pickupProgress: 'trip.pickup-progress',
  /** DRIVER_ARRIVED: the no-show wait is over (driver may cancel without fault; passenger reminded). */
  noShow: 'trip.no-show',
  /** IN_PROGRESS / PICKED_UP: still running far past its estimate → flag for admins. */
  stuck: 'trip.stuck',
  /** Not started long after accept → cancelled by the system (safety net). */
  pickupCap: 'trip.pickup-cap',
} as const;

export const ALL_TRIP_JOBS = Object.values(TRIP_JOBS);

type TimeoutSettings = Pick<
  Settings,
  'notMovingMinMin' | 'notMovingEtaFactor' | 'notMovingRecheckMin' | 'noShowWaitMin' | 'stuckTripMinMin' | 'stuckDurationFactor' | 'pickupHardCapMin'
>;

const MIN = 60_000;

/** First "not moving" check: max(notMovingMinMin, notMovingEtaFactor × pickup ETA) after accept. */
export function pickupCheckAt(acceptedAt: number, pickupEtaMin: number | null, s: TimeoutSettings): number {
  const eta = pickupEtaMin && pickupEtaMin > 0 ? pickupEtaMin : 0;
  return acceptedAt + Math.max(s.notMovingMinMin, s.notMovingEtaFactor * eta) * MIN;
}

/** The next check after a nudge. */
export const pickupRecheckAt = (now: number, s: TimeoutSettings): number => now + s.notMovingRecheckMin * MIN;

/** From when the driver may cancel as a no-show. */
export const noShowAt = (arrivedAt: number, s: TimeoutSettings): number => arrivedAt + s.noShowWaitMin * MIN;

/** When a started trip counts as stuck: max(stuckTripMinMin, stuckDurationFactor × estimated minutes) after start. */
export function stuckAt(startedAt: number, durationMin: number, s: TimeoutSettings): number {
  return startedAt + Math.max(s.stuckTripMinMin, s.stuckDurationFactor * Math.max(0, durationMin)) * MIN;
}

export const pickupCapAt = (acceptedAt: number, s: TimeoutSettings): number => acceptedAt + s.pickupHardCapMin * MIN;

/**
 * Verdict of a "not moving" check. [atAcceptM]: distance to the pickup at accept (null = unknown, then any position
 * counts as the baseline); [nowM]: distance now (null = no fresh GPS fix, counts as not moving). "strike" = nudge,
 * "reassign" = [strikes] (earlier failed checks) reached [maxStrikes] − 1.
 */
export function pickupProgressVerdict(p: {
  atAcceptM: number | null;
  nowM: number | null;
  minProgressM: number;
  strikes: number;
  maxStrikes?: number;
}): 'moving' | 'strike' | 'reassign' {
  const moved = p.nowM !== null && (p.atAcceptM === null || p.atAcceptM - p.nowM >= p.minProgressM);
  if (moved) return 'moving';
  return p.strikes + 1 >= (p.maxStrikes ?? 2) ? 'reassign' : 'strike';
}
