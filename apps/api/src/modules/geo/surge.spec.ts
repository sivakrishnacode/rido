import { smoothSurge, surgeFor } from './surge.js';

const base = { sensitivity: 0.1, minRequests: 3, maxMultiplier: 1.5 };

describe('surgeFor', () => {
  it('has no surge with too few requests', () => {
    expect(surgeFor({ ...base, requests: 2, freeDrivers: 0 })).toMatchObject({ multiplier: 1, level: 'normal' });
  });

  it('has no surge when drivers cover demand', () => {
    expect(surgeFor({ ...base, requests: 6, freeDrivers: 8 })).toMatchObject({ multiplier: 1, level: 'busy' });
  });

  it('grows with the demand/supply ratio and rounds down to 0.05', () => {
    expect(surgeFor({ ...base, requests: 9, freeDrivers: 3 })).toMatchObject({ ratio: 3, multiplier: 1.2, level: 'high' });
    expect(surgeFor({ ...base, requests: 5, freeDrivers: 2 }).multiplier).toBe(1.15);
  });

  it('is capped at the max multiplier', () => {
    expect(surgeFor({ ...base, requests: 60, freeDrivers: 0 }).multiplier).toBe(1.5);
  });
});

describe('smoothSurge', () => {
  // A tiny fake grid: A in the middle, B–G around it.
  const ring: Record<string, string[]> = { A: ['B', 'C', 'D', 'E', 'F', 'G'] };
  const neighbours = (c: string): string[] => ring[c] ?? ['A'];

  it('spreads some surge to neighbours of a busy cell and softens the spike', () => {
    const out = smoothSurge(new Map([['A', 1.5]]), neighbours);
    expect(out.get('A')).toBe(1.3); // 1.5×0.6 + 1×0.4
    expect(out.get('B')).toBe(1.2); // 1×0.6 + 1.5×0.4
  });

  it('returns nothing without surge', () => {
    expect(smoothSurge(new Map([['A', 1]]), neighbours).size).toBe(0);
  });
});
