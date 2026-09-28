import { CancelCode, CancelFault, CancelledBy } from '../../generated/prisma/enums.js';

/**
 * What was known when a trip was cancelled (like Namma Yatri's `CancellationSignals`). Stored as JSON on the
 * `TripCancellation` row next to the verdict, so an admin can see why it was judged that way.
 */
export interface CancelSignals {
  readonly by: CancelledBy;
  readonly code: CancelCode;
  /** Trip status when it was cancelled. */
  readonly fromStatus: string;
  /** A driver had accepted it. */
  readonly hasDriver: boolean;
  /** The driver had marked "Arrived". */
  readonly isArrived: boolean;
  /** Seconds the driver had waited at the pickup (null before arriving). */
  readonly waitedSec: number | null;
  /** Seconds since the driver accepted (null without a driver). */
  readonly sinceAcceptSec: number | null;
  /** Straight-line metres from the driver to the pickup at accept and now (null = unknown). */
  readonly atAcceptM: number | null;
  readonly nowM: number | null;
  /** The driver is now [MOVING_AWAY_M] or more farther from the pickup than when they accepted. */
  readonly isMovingAway: boolean;
  /** Minutes the driver must wait before a no-show cancel (the `noShowWaitMin` setting at the time). */
  readonly noShowWaitMin: number;
  /** Free waiting minutes (the `freeWaitMin` setting): a passenger who cancels after them is at fault. */
  readonly freeWaitMin: number;
}

export interface FaultVerdict {
  readonly fault: CancelFault;
  /** Name of the rule that decided (shown in admin; like Namma Yatri's mandatory `rule`). */
  readonly rule: string;
}

/** A passenger cancel this soon after accept is free of fault (they may just have changed their mind). */
export const EARLY_CANCEL_SEC = 120;
/** "Moving away": the driver is this much farther from the pickup than at accept. */
export const MOVING_AWAY_M = 300;

/** Metres farther from the pickup than at accept, or null when either distance is unknown. */
export function movedAwayM(atAcceptM: number | null, nowM: number | null): number | null {
  return atAcceptM === null || nowM === null ? null : nowM - atAcceptM;
}

/**
 * Who was at fault for a cancellation. One pure function, first matching rule wins:
 * - nobody had accepted yet, or no drivers → NONE;
 * - system: DRIVER_NOT_MOVING → DRIVER; STUCK (never started) → DRIVER before arrival, SHARED after; other → NONE;
 * - admin → NONE;
 * - driver: BUTTERFLY_MISMATCH → PASSENGER; PASSENGER_NO_SHOW (only allowed after the wait) → PASSENGER; after
 *   arriving and waiting the no-show time with PASSENGER_UNREACHABLE / PASSENGER_ASKED_TO_CANCEL → SHARED;
 *   anything else → DRIVER;
 * - passenger: the driver was moving away from the pickup → DRIVER; within [EARLY_CANCEL_SEC] of accept → NONE;
 *   after the driver arrived and waited the free minutes → PASSENGER, sooner after arrival → SHARED;
 *   DRIVER_ASKED_TO_CANCEL → SHARED (their word against the driver's); WAIT_TOO_LONG / DRIVER_TOO_FAR → NONE;
 *   otherwise (changed their mind while the driver was on the way) → PASSENGER.
 */
export function faultVerdict(s: CancelSignals): FaultVerdict {
  if (s.code === CancelCode.NO_DRIVERS) return { fault: CancelFault.NONE, rule: 'no_drivers' };
  if (!s.hasDriver) return { fault: CancelFault.NONE, rule: 'no_driver_yet' };
  switch (s.by) {
    case CancelledBy.SYSTEM:
      if (s.code === CancelCode.DRIVER_NOT_MOVING) return { fault: CancelFault.DRIVER, rule: 'driver_not_moving' };
      if (s.code === CancelCode.STUCK) {
        return s.isArrived ? { fault: CancelFault.SHARED, rule: 'never_started_after_arrival' } : { fault: CancelFault.DRIVER, rule: 'never_reached_pickup' };
      }
      return { fault: CancelFault.NONE, rule: 'system' };
    case CancelledBy.ADMIN:
      return { fault: CancelFault.NONE, rule: 'admin' };
    case CancelledBy.DRIVER: {
      if (s.code === CancelCode.BUTTERFLY_MISMATCH) return { fault: CancelFault.PASSENGER, rule: 'butterfly_mismatch' };
      if (s.code === CancelCode.PASSENGER_NO_SHOW) return { fault: CancelFault.PASSENGER, rule: 'passenger_no_show' };
      const waitedNoShow = s.isArrived && (s.waitedSec ?? 0) >= s.noShowWaitMin * 60;
      if (waitedNoShow && (s.code === CancelCode.PASSENGER_UNREACHABLE || s.code === CancelCode.PASSENGER_ASKED_TO_CANCEL)) {
        return { fault: CancelFault.SHARED, rule: 'driver_after_wait' };
      }
      return { fault: CancelFault.DRIVER, rule: s.isArrived ? 'driver_after_arrival' : 'driver_before_arrival' };
    }
    case CancelledBy.PASSENGER: {
      if (!s.isArrived && s.isMovingAway) return { fault: CancelFault.DRIVER, rule: 'driver_moving_away' };
      if ((s.sinceAcceptSec ?? 0) < EARLY_CANCEL_SEC) return { fault: CancelFault.NONE, rule: 'early_passenger_cancel' };
      if (s.isArrived) {
        return (s.waitedSec ?? 0) >= s.freeWaitMin * 60
          ? { fault: CancelFault.PASSENGER, rule: 'passenger_after_wait' }
          : { fault: CancelFault.SHARED, rule: 'passenger_on_arrival' };
      }
      if (s.code === CancelCode.DRIVER_ASKED_TO_CANCEL) return { fault: CancelFault.SHARED, rule: 'driver_asked_to_cancel' };
      if (s.code === CancelCode.WAIT_TOO_LONG || s.code === CancelCode.DRIVER_TOO_FAR) return { fault: CancelFault.NONE, rule: 'driver_slow' };
      return { fault: CancelFault.PASSENGER, rule: 'passenger_late_cancel' };
    }
  }
  return { fault: CancelFault.NONE, rule: 'no_rule_matched' };
}

/** Builds the signals for a cancel at [now] of a trip in [trip]'s state. */
export function cancelSignals(p: {
  by: CancelledBy;
  code: CancelCode;
  trip: { status: string; driverId: string | null; assignedAt: Date | null; arrivedAt: Date | null; acceptDistanceM: number | null };
  nowM: number | null;
  now: Date;
  noShowWaitMin: number;
  freeWaitMin: number;
}): CancelSignals {
  const { trip, now } = p;
  const sec = (from: Date | null): number | null => (from ? Math.max(0, Math.round((now.getTime() - from.getTime()) / 1000)) : null);
  const away = movedAwayM(trip.acceptDistanceM, p.nowM);
  return {
    by: p.by,
    code: p.code,
    fromStatus: trip.status,
    hasDriver: trip.driverId !== null,
    isArrived: trip.arrivedAt !== null,
    waitedSec: sec(trip.arrivedAt),
    sinceAcceptSec: sec(trip.assignedAt),
    atAcceptM: trip.acceptDistanceM,
    nowM: p.nowM,
    isMovingAway: away !== null && away >= MOVING_AWAY_M,
    noShowWaitMin: p.noShowWaitMin,
    freeWaitMin: p.freeWaitMin,
  };
}
