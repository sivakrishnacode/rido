import type { Settings } from '../settings/settings.defaults.js';

/**
 * Driver ranking for dispatch (like Namma Yatri's intelligent pool, `DriverIntelligentPoolConfig`): road ETA to the
 * pickup, made longer for drivers who often ignore/decline offers or cancel after accepting, and a little shorter for
 * drivers who have waited long for a trip. Counters live in Redis, one small hash per driver per day (UTC), summed
 * over the last 7 days.
 */

/** Days summed for the ratios (today plus the 6 before). */
export const RANK_WINDOW_DAYS = 7;
/** A day's hash outlives the window by a day, then Redis drops it. */
export const RANK_BUCKET_TTL_S = 8 * 86_400;

/** Hash fields of one day's counters. */
export const STAT_FIELDS = { offered: 'o', accepted: 'a', declined: 'd', ignored: 'i', cancelled: 'c' } as const;
export type StatEvent = keyof typeof STAT_FIELDS;

/** Per-driver offer counters over the window. */
export interface OfferStats {
  /** Offers sent to the driver. */
  readonly offered: number;
  readonly accepted: number;
  /** Said no. */
  readonly declined: number;
  /** Let the offer run out. */
  readonly ignored: number;
  /** Cancelled after accepting, judged the driver's fault. */
  readonly cancelled: number;
}

export const EMPTY_STATS: OfferStats = { offered: 0, accepted: 0, declined: 0, ignored: 0, cancelled: 0 };

/** `drv:stats:<id>:<yyyymmdd>` for the UTC day of [now]. */
export function statsKey(driverId: string, now: number): string {
  return `drv:stats:${driverId}:${new Date(now).toISOString().slice(0, 10).replaceAll('-', '')}`;
}

/** The day keys of the window ending at [now], newest first. */
export function statsKeys(driverId: string, now: number, days = RANK_WINDOW_DAYS): string[] {
  return Array.from({ length: days }, (_, i) => statsKey(driverId, now - i * 86_400_000));
}

/** Sums day hashes (HGETALL replies; missing days are `{}` or null) into [OfferStats]. */
export function sumStats(days: readonly (Record<string, string> | null | undefined)[]): OfferStats {
  const total = { ...EMPTY_STATS };
  for (const day of days) {
    if (!day) continue;
    for (const [name, field] of Object.entries(STAT_FIELDS) as [StatEvent, string][]) {
      const n = Number(day[field] ?? 0);
      if (Number.isFinite(n) && n > 0) total[name] += n;
    }
  }
  return total;
}

/** Idle-time keys: when the driver's last trip ended, and when they last went online (epoch ms). */
export const lastTripEndKey = (driverId: string): string => `drv:lastTripEnd:${driverId}`;
export const onlineSinceKey = (driverId: string): string => `drv:onlineSince:${driverId}`;
/** Idle keys are only read for ranking (full boost at `rankIdleFullMin`), so a day is plenty. */
export const IDLE_KEY_TTL_S = 86_400;

/** Waiting since the later of the last trip end and going online; null when neither is known. */
export function idleSince(lastTripEnd: string | null, onlineSince: string | null): number | null {
  const times = [lastTripEnd, onlineSince].map(Number).filter((t) => Number.isFinite(t) && t > 0);
  return times.length ? Math.max(...times) : null;
}

export type RankSettings = Pick<Settings, 'rankEnabled' | 'rankWeightAccept' | 'rankWeightCancel' | 'rankIdleMaxBoost' | 'rankIdleFullMin' | 'rankMinOffers'>;

/** How the score came out, for logs and the admin page. */
export interface RankBreakdown {
  /** accepted ÷ answered offers (accepted + declined + ignored); null until `rankMinOffers` offers. */
  readonly acceptRatio: number | null;
  /** driver-fault cancels ÷ accepted; null until `rankMinOffers` offers. */
  readonly cancelRatio: number | null;
  /** Share of the ETA taken off for waiting, 0 … `rankIdleMaxBoost`. */
  readonly idleShare: number;
}

const clamp01 = (n: number): number => Math.min(1, Math.max(0, n));

/** The ratios behind a score: neutral (null) below `rankMinOffers` offers, so new drivers are not held back. */
export function reliability(stats: OfferStats, s: Pick<Settings, 'rankMinOffers'>): Pick<RankBreakdown, 'acceptRatio' | 'cancelRatio'> {
  const answered = stats.accepted + stats.declined + stats.ignored;
  if (stats.offered < Math.max(1, s.rankMinOffers) || answered === 0) return { acceptRatio: null, cancelRatio: null };
  return {
    acceptRatio: clamp01(stats.accepted / answered),
    cancelRatio: stats.accepted > 0 ? clamp01(stats.cancelled / stats.accepted) : 0,
  };
}

/**
 * Ranking minutes for one candidate (lower = offered first):
 *
 *   eta × (1 + wAccept·(1 − acceptRatio) + wCancel·cancelRatio) − idleBoost
 *   idleBoost = eta × rankIdleMaxBoost × min(1, idleMin ÷ rankIdleFullMin)
 *
 * The ratios count only from `rankMinOffers` offers. The idle boost is a share of the driver's own ETA (at most
 * `rankIdleMaxBoost`, 15 %), so waiting long never lets a far driver jump a much nearer one. `rankEnabled` off →
 * the plain ETA.
 */
export function rankScore(p: { etaMin: number; stats: OfferStats; idleSince: number | null; now: number }, s: RankSettings): { score: number } & RankBreakdown {
  const eta = Math.max(0, p.etaMin);
  if (!s.rankEnabled) return { score: eta, acceptRatio: null, cancelRatio: null, idleShare: 0 };
  const { acceptRatio, cancelRatio } = reliability(p.stats, s);
  const penalty = Math.max(0, s.rankWeightAccept) * (1 - (acceptRatio ?? 1)) + Math.max(0, s.rankWeightCancel) * (cancelRatio ?? 0);
  const idleMin = p.idleSince === null ? 0 : Math.max(0, p.now - p.idleSince) / 60_000;
  const idleShare = clamp01(s.rankIdleMaxBoost) * (s.rankIdleFullMin > 0 ? Math.min(1, idleMin / s.rankIdleFullMin) : 1);
  return { score: eta * (1 + penalty) - eta * idleShare, acceptRatio, cancelRatio, idleShare };
}

/** Admin driver page: the 7-day counters and the ratios dispatch uses. */
export interface DriverOfferStats extends OfferStats {
  readonly days: number;
  /** accepted ÷ answered offers, 0–1 (null without answers). */
  readonly acceptRate: number | null;
  /** Used for ranking yet (at least `rankMinOffers` offers)? */
  readonly isRanked: boolean;
  readonly minOffers: number;
}

export function driverOfferStats(stats: OfferStats, s: Pick<Settings, 'rankMinOffers'>): DriverOfferStats {
  const answered = stats.accepted + stats.declined + stats.ignored;
  return {
    ...stats,
    days: RANK_WINDOW_DAYS,
    acceptRate: answered > 0 ? Math.round((stats.accepted / answered) * 1000) / 1000 : null,
    isRanked: reliability(stats, s).acceptRatio !== null,
    minOffers: s.rankMinOffers,
  };
}
