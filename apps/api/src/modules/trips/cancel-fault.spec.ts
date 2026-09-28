import { type CancelSignals, cancelSignals, EARLY_CANCEL_SEC, faultVerdict, MOVING_AWAY_M } from './cancel-fault.js';

/** A driver on the way, accepted 5 min ago, getting closer. */
const base: CancelSignals = {
  by: 'PASSENGER',
  code: 'CHANGED_MIND',
  fromStatus: 'DRIVER_ASSIGNED',
  hasDriver: true,
  isArrived: false,
  waitedSec: null,
  sinceAcceptSec: 300,
  atAcceptM: 1500,
  nowM: 900,
  isMovingAway: false,
  noShowWaitMin: 5,
  freeWaitMin: 3,
};
const verdict = (s: Partial<CancelSignals>) => faultVerdict({ ...base, ...s });
const arrived = (waitedSec: number): Partial<CancelSignals> => ({ fromStatus: 'DRIVER_ARRIVED', isArrived: true, waitedSec });

describe('cancellation fault verdict', () => {
  it('blames nobody before a driver accepted, or for no drivers', () => {
    expect(verdict({ hasDriver: false, sinceAcceptSec: null })).toEqual({ fault: 'NONE', rule: 'no_driver_yet' });
    expect(verdict({ by: 'SYSTEM', code: 'NO_DRIVERS' }).fault).toBe('NONE');
  });

  it('a driver cancel before arrival is the driver\'s fault', () => {
    expect(verdict({ by: 'DRIVER', code: 'VEHICLE_ISSUE' })).toEqual({ fault: 'DRIVER', rule: 'driver_before_arrival' });
    expect(verdict({ by: 'DRIVER', code: 'TOO_FAR' }).fault).toBe('DRIVER');
    expect(verdict({ by: 'DRIVER', code: 'PASSENGER_UNREACHABLE' }).fault).toBe('DRIVER');
  });

  it('except a Butterfly mismatch (the passenger\'s) and a system not-moving cancel (still the driver\'s)', () => {
    expect(verdict({ by: 'DRIVER', code: 'BUTTERFLY_MISMATCH' })).toEqual({ fault: 'PASSENGER', rule: 'butterfly_mismatch' });
    expect(verdict({ by: 'SYSTEM', code: 'DRIVER_NOT_MOVING' })).toEqual({ fault: 'DRIVER', rule: 'driver_not_moving' });
  });

  it('a no-show after the wait is the passenger\'s fault', () => {
    expect(verdict({ by: 'DRIVER', code: 'PASSENGER_NO_SHOW', ...arrived(320) })).toEqual({ fault: 'PASSENGER', rule: 'passenger_no_show' });
  });

  it('after the no-show wait, "unreachable" or "asked me to cancel" is shared; sooner it is the driver\'s', () => {
    expect(verdict({ by: 'DRIVER', code: 'PASSENGER_UNREACHABLE', ...arrived(300) }).fault).toBe('SHARED');
    expect(verdict({ by: 'DRIVER', code: 'PASSENGER_ASKED_TO_CANCEL', ...arrived(299) })).toEqual({ fault: 'DRIVER', rule: 'driver_after_arrival' });
  });

  it('a passenger cancel within 2 minutes of accept is nobody\'s fault', () => {
    expect(verdict({ sinceAcceptSec: EARLY_CANCEL_SEC - 1 })).toEqual({ fault: 'NONE', rule: 'early_passenger_cancel' });
    expect(verdict({ sinceAcceptSec: EARLY_CANCEL_SEC }).fault).toBe('PASSENGER');
  });

  it('a passenger cancel after the driver waited the free minutes is the passenger\'s; sooner it is shared', () => {
    expect(verdict({ ...arrived(180) })).toEqual({ fault: 'PASSENGER', rule: 'passenger_after_wait' });
    expect(verdict({ ...arrived(60) })).toEqual({ fault: 'SHARED', rule: 'passenger_on_arrival' });
  });

  it('a passenger cancel because the driver was moving away is the driver\'s, even right after accept', () => {
    expect(verdict({ code: 'DRIVER_TOO_FAR', isMovingAway: true, sinceAcceptSec: 60 })).toEqual({ fault: 'DRIVER', rule: 'driver_moving_away' });
  });

  it('a slow driver or "driver asked me to cancel" is not held against the passenger', () => {
    expect(verdict({ code: 'WAIT_TOO_LONG' }).fault).toBe('NONE');
    expect(verdict({ code: 'DRIVER_TOO_FAR' }).fault).toBe('NONE');
    expect(verdict({ code: 'DRIVER_ASKED_TO_CANCEL' }).fault).toBe('SHARED');
  });

  it('system STUCK: the driver\'s before arrival, shared after; admins blame nobody', () => {
    expect(verdict({ by: 'SYSTEM', code: 'STUCK' }).fault).toBe('DRIVER');
    expect(verdict({ by: 'SYSTEM', code: 'STUCK', ...arrived(3000) }).fault).toBe('SHARED');
    expect(verdict({ by: 'ADMIN', code: 'OTHER' }).fault).toBe('NONE');
  });

  it('builds the signals from the trip and the driver\'s distance now', () => {
    const now = new Date('2026-09-28T10:10:00Z');
    const s = cancelSignals({
      by: 'PASSENGER',
      code: 'DRIVER_TOO_FAR',
      trip: { status: 'DRIVER_ASSIGNED', driverId: 'd1', assignedAt: new Date('2026-09-28T10:04:00Z'), arrivedAt: null, acceptDistanceM: 1000 },
      nowM: 1000 + MOVING_AWAY_M,
      now,
      noShowWaitMin: 5,
      freeWaitMin: 3,
    });
    expect(s).toMatchObject({ hasDriver: true, isArrived: false, waitedSec: null, sinceAcceptSec: 360, isMovingAway: true });
    const unknown = cancelSignals({ ...s, trip: { status: 'DRIVER_ASSIGNED', driverId: 'd1', assignedAt: null, arrivedAt: null, acceptDistanceM: null }, nowM: 50, now, by: 'PASSENGER', code: 'OTHER' });
    expect(unknown.isMovingAway).toBe(false);
  });
});
