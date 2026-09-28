import { SETTING_DEFAULTS, type Settings } from '../settings/settings.defaults.js';
import { applyWomenPref } from '../drivers/women-drivers.js';
import { WomenDriverPref } from '../../generated/prisma/enums.js';
import { assignBatch } from './batch-assign.js';
import {
  driverOfferStats,
  EMPTY_STATS,
  idleSince,
  type OfferStats,
  rankScore,
  reliability,
  statsKey,
  statsKeys,
  sumStats,
} from './driver-rank.js';

const s: Settings = SETTING_DEFAULTS;
const NOW = Date.UTC(2026, 8, 28, 10, 0, 0);
const MIN = 60_000;
const stats = (p: Partial<OfferStats>): OfferStats => ({ ...EMPTY_STATS, ...p });
/** A driver who answered [offered] offers, accepting [accepted] and cancelling [cancelled] of those. */
const record = (offered: number, accepted: number, cancelled = 0): OfferStats =>
  stats({ offered, accepted, declined: Math.ceil((offered - accepted) / 2), ignored: Math.floor((offered - accepted) / 2), cancelled });
const score = (etaMin: number, st: OfferStats = EMPTY_STATS, idleMin: number | null = null, settings = s): number =>
  rankScore({ etaMin, stats: st, idleSince: idleMin === null ? null : NOW - idleMin * MIN, now: NOW }, settings).score;

describe('offer counters', () => {
  it('keys one hash per driver per UTC day', () => {
    expect(statsKey('d1', NOW)).toBe('drv:stats:d1:20260928');
    expect(statsKey('d1', Date.UTC(2026, 8, 28, 23, 59))).toBe('drv:stats:d1:20260928');
    expect(statsKey('d1', Date.UTC(2026, 8, 29, 0, 0))).toBe('drv:stats:d1:20260929');
  });

  it('reads the last 7 days, newest first, across a month end', () => {
    const keys = statsKeys('d1', Date.UTC(2026, 9, 2, 12));
    expect(keys).toHaveLength(7);
    expect(keys[0]).toBe('drv:stats:d1:20261002');
    expect(keys[6]).toBe('drv:stats:d1:20260926');
  });

  it('sums day hashes, skipping missing days and junk', () => {
    const total = sumStats([{ o: '3', a: '2', i: '1' }, null, {}, { o: '2', a: '1', d: '1', c: '1' }, { o: 'x' }]);
    expect(total).toEqual({ offered: 5, accepted: 3, declined: 1, ignored: 1, cancelled: 1 });
  });

  it('idle since the later of the last trip end and going online', () => {
    expect(idleSince(String(NOW - 10 * MIN), String(NOW - 40 * MIN))).toBe(NOW - 10 * MIN);
    expect(idleSince(null, String(NOW - 40 * MIN))).toBe(NOW - 40 * MIN);
    expect(idleSince(null, null)).toBeNull();
  });
});

describe('reliability', () => {
  it('is neutral below rankMinOffers offers', () => {
    expect(reliability(record(9, 0), s)).toEqual({ acceptRatio: null, cancelRatio: null });
    expect(score(5, record(9, 0))).toBe(5);
  });

  it('counts from rankMinOffers: accepted ÷ answered, cancels ÷ accepted', () => {
    expect(reliability(record(10, 5, 1), s)).toEqual({ acceptRatio: 0.5, cancelRatio: 0.2 });
    // No acceptances yet: nothing to cancel.
    expect(reliability(record(10, 0), s).cancelRatio).toBe(0);
  });

  it('ignores offers still open (answered is the denominator)', () => {
    expect(reliability(stats({ offered: 12, accepted: 10 }), s).acceptRatio).toBe(1);
  });
});

describe('rankScore', () => {
  it('eta × (1 + wAccept·(1 − accept) + wCancel·cancel)', () => {
    // 50 % accepted, 20 % cancelled: 10 × (1 + 0.5·0.5 + 1·0.2) = 14.5
    expect(score(10, record(10, 5, 1))).toBeCloseTo(14.5);
    expect(score(10, record(20, 20))).toBe(10);
  });

  it('a worse acceptance history ranks second at the same ETA', () => {
    expect(score(4, record(20, 8))).toBeGreaterThan(score(4, record(20, 19)));
    expect(score(4, record(20, 19, 5))).toBeGreaterThan(score(4, record(20, 19)));
  });

  it('idle bonus grows to rankIdleMaxBoost at rankIdleFullMin minutes, then stops', () => {
    expect(score(10, EMPTY_STATS, 0)).toBe(10);
    expect(score(10, EMPTY_STATS, 15)).toBeCloseTo(10 * (1 - 0.075));
    expect(score(10, EMPTY_STATS, 30)).toBeCloseTo(8.5);
    expect(score(10, EMPTY_STATS, 300)).toBeCloseTo(8.5);
    expect(score(10, EMPTY_STATS, null)).toBe(10);
  });

  it('keeps ETA dominant: a long wait never beats a driver more than 15 % nearer', () => {
    for (const eta of [1, 3, 8, 20]) {
      const near = eta * 0.84;
      expect(score(eta, EMPTY_STATS, 600)).toBeGreaterThan(score(near, EMPTY_STATS, 0));
      expect(score(eta, record(50, 50), 600)).toBeGreaterThan(score(near, record(50, 50), 0));
    }
  });

  it('keeps ETA dominant: a perfect record never beats a driver half as far with a fair record', () => {
    // Fair = 80 % accepted, no cancels (factor 1.1); the far driver is perfect and idle.
    expect(score(10, record(20, 20), 60)).toBeGreaterThan(score(5, record(20, 16), 0));
  });

  it('ETA 0 (at the pickup) stays 0 whatever the record', () => {
    expect(score(0, record(20, 0, 0))).toBe(0);
  });

  it('rankEnabled off: the plain ETA', () => {
    expect(score(10, record(10, 0), 60, { ...s, rankEnabled: false })).toBe(10);
  });

  it('feeds the Butterfly head start and the batch: the reliable driver is offered first', () => {
    const cands = [
      { driverId: 'flaky', etaMin: score(4, record(20, 6)) },
      { driverId: 'steady', etaMin: score(4, record(20, 20)) },
    ];
    const queue = assignBatch([{ tripId: 'A', createdAt: new Date(NOW), candidates: cands }]).get('A');
    expect(queue).toEqual(['steady', 'flaky']);
    // PREFERRED: a woman with a worse record still goes first over a man (8 min head start).
    const pref = applyWomenPref(cands, WomenDriverPref.PREFERRED, new Set(['flaky']));
    expect(assignBatch([{ tripId: 'B', createdAt: new Date(NOW), candidates: pref }]).get('B')).toEqual(['flaky', 'steady']);
  });
});

describe('driverOfferStats (admin)', () => {
  it('shows the counters, the accept rate and whether ranking uses them yet', () => {
    expect(driverOfferStats(stats({ offered: 4, accepted: 3, ignored: 1 }), s)).toMatchObject({ acceptRate: 0.75, isRanked: false, minOffers: 10, days: 7 });
    expect(driverOfferStats(record(10, 7), s)).toMatchObject({ acceptRate: 0.7, isRanked: true });
    expect(driverOfferStats(EMPTY_STATS, s).acceptRate).toBeNull();
  });
});
