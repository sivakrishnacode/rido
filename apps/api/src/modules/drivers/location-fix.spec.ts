import { MAX_BATCH_FIXES, MAX_FIX_AGE_MS, sanitizeBatch, sanitizeFix } from './location-fix.js';

const NOW = 1_800_000_000_000;

describe('sanitizeFix', () => {
  it('accepts an old app\'s {lat, lng} as a fix taken now', () => {
    expect(sanitizeFix({ lat: 11.01, lng: 76.95 }, NOW)).toEqual({ lat: 11.01, lng: 76.95, ts: NOW, acc: null, spd: null, hdg: null, mock: false });
  });

  it('keeps the rich fields of a new app', () => {
    const f = sanitizeFix({ lat: 11.01, lng: 76.95, ts: NOW - 5000, acc: 8.5, spd: 7.2, hdg: 181, mock: true }, NOW);
    expect(f).toEqual({ lat: 11.01, lng: 76.95, ts: NOW - 5000, acc: 8.5, spd: 7.2, hdg: 181, mock: true });
  });

  it('drops bad coordinates, (0, 0) and fixes older than 12 h', () => {
    for (const bad of [null, 'x', {}, { lat: 91, lng: 0 }, { lat: 11, lng: 181 }, { lat: 0, lng: 0 }, { lat: Number.NaN, lng: 1 }, { lat: '11', lng: '76' }]) {
      expect(sanitizeFix(bad, NOW)).toBeNull();
    }
    expect(sanitizeFix({ lat: 11, lng: 76, ts: NOW - MAX_FIX_AGE_MS - 1 }, NOW)).toBeNull();
  });

  it('clamps a phone clock running ahead to the server time and ignores out-of-range extras', () => {
    const f = sanitizeFix({ lat: 11, lng: 76, ts: NOW + 3_600_000, acc: -1, spd: 500, hdg: 400, mock: 'yes' }, NOW);
    expect(f).toMatchObject({ ts: NOW, acc: null, spd: null, hdg: null, mock: false });
  });
});

describe('sanitizeBatch', () => {
  it('sorts by time, drops invalid fixes and keeps the newest when over the cap', () => {
    const batch = sanitizeBatch([{ lat: 11, lng: 76, ts: NOW - 1000 }, { lat: 0, lng: 0 }, { lat: 11.1, lng: 76, ts: NOW - 3000 }], NOW);
    expect(batch.map((f) => f.ts)).toEqual([NOW - 3000, NOW - 1000]);
    const big = Array.from({ length: MAX_BATCH_FIXES + 10 }, (_, i) => ({ lat: 11, lng: 76, ts: NOW - 100_000 + i }));
    const capped = sanitizeBatch(big, NOW);
    expect(capped).toHaveLength(MAX_BATCH_FIXES);
    expect(capped[capped.length - 1].ts).toBe(NOW - 100_000 + MAX_BATCH_FIXES + 9);
    expect(sanitizeBatch('nope', NOW)).toEqual([]);
  });
});
