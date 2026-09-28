import type { Settings } from '../settings/settings.defaults.js';

/** The sliding window of the driver cancellation rate. */
export const CANCEL_RATE_WINDOW_MS = 7 * 86_400_000;

export type CancelRateLevel = 'OK' | 'NUDGE' | 'BLOCK';

type RateSettings = Pick<Settings, 'cancelRateMinTrips' | 'cancelRateNudge' | 'cancelRateBlock'>;
type BlockSettings = Pick<Settings, 'cancelBlockHours' | 'cancelBlockRepeatHours'>;

/**
 * Driver-fault cancellations ÷ assigned trips in the window, and what it means: nothing below
 * `cancelRateMinTrips` assigned trips (too few to judge), a nudge from `cancelRateNudge`, a pause from
 * `cancelRateBlock` (like Namma Yatri's `nudgeOrBlockDriver`).
 */
export function cancelRateLevel(p: { cancelled: number; assigned: number }, s: RateSettings): { rate: number; level: CancelRateLevel } {
  const assigned = Math.max(p.assigned, p.cancelled);
  const rate = assigned > 0 ? Math.round((p.cancelled / assigned) * 1000) / 1000 : 0;
  if (assigned < Math.max(1, s.cancelRateMinTrips)) return { rate, level: 'OK' };
  if (rate >= s.cancelRateBlock) return { rate, level: 'BLOCK' };
  if (rate >= s.cancelRateNudge) return { rate, level: 'NUDGE' };
  return { rate, level: 'OK' };
}

/**
 * Start of the window at [now]: 7 days back, but never before the end of the driver's last pause (counting starts
 * again after one, so a single cancel right after a pause doesn't pause them again).
 */
export function cancelRateSince(now: number, lastBlockEnd: Date | null): Date {
  return new Date(Math.max(now - CANCEL_RATE_WINDOW_MS, lastBlockEnd && lastBlockEnd.getTime() <= now ? lastBlockEnd.getTime() : 0));
}

/** Pause length: `cancelBlockRepeatHours` when the driver was already paused in the last 7 days. */
export function blockHours(hadRecentBlock: boolean, s: BlockSettings): number {
  return hadRecentBlock ? s.cancelBlockRepeatHours : s.cancelBlockHours;
}

/** Passengers are never blocked; admins see this: bookings, their own cancels and the ones judged their fault. */
export interface PassengerCancelRate {
  readonly since: string;
  readonly booked: number;
  readonly cancelled: number;
  readonly atFault: number;
  /** cancelled ÷ booked, and atFault ÷ booked (3 decimals; 0 without bookings). */
  readonly rate: number;
  readonly faultRate: number;
}

export function passengerCancelRate(p: { since: Date; booked: number; cancelled: number; atFault: number }): PassengerCancelRate {
  const r = (n: number) => (p.booked > 0 ? Math.round((Math.min(n, p.booked) / p.booked) * 1000) / 1000 : 0);
  return { since: p.since.toISOString(), booked: p.booked, cancelled: p.cancelled, atFault: p.atFault, rate: r(p.cancelled), faultRate: r(p.atFault) };
}

/** "You've cancelled 2 of your last 5 rides" (the nudge and the app banner). */
export function cancelRateMessage(p: { cancelled: number; assigned: number; level: CancelRateLevel }, s: RateSettings & BlockSettings): { title: string; body: string } {
  const title = `You've cancelled ${p.cancelled} of your last ${p.assigned} rides`;
  if (p.level === 'BLOCK') {
    return { title: 'Account paused', body: `${title} this week, so you can't go online for a while. Only accept rides you can reach` };
  }
  return { title, body: `If you cancel ${Math.round(s.cancelRateBlock * 100)}% of your rides, you can't go online for ${s.cancelBlockHours} h. Only accept rides you can reach` };
}
