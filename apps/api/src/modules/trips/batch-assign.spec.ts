import { assignBatch } from './batch-assign.js';

const t = (s: number): Date => new Date(2026, 8, 25, 10, 0, s);

describe('assignBatch', () => {
  it('gives each trip its fastest driver', () => {
    const out = assignBatch([
      { tripId: 'A', createdAt: t(0), candidates: [{ driverId: 'd1', etaMin: 4 }, { driverId: 'd2', etaMin: 2 }] },
    ]);
    expect(out.get('A')).toEqual(['d2', 'd1']);
  });

  it('does not give the same driver to two riders; the batch is solved together', () => {
    // d1 is closest to both, but B has no other option: A should get d2 (3 min) and B d1.
    const out = assignBatch([
      { tripId: 'A', createdAt: t(0), candidates: [{ driverId: 'd1', etaMin: 2 }, { driverId: 'd2', etaMin: 3 }] },
      { tripId: 'B', createdAt: t(1), candidates: [{ driverId: 'd1', etaMin: 1 }] },
    ]);
    expect(out.get('B')?.[0]).toBe('d1');
    expect(out.get('A')?.[0]).toBe('d2');
  });

  it('breaks ETA ties by booking time and keeps promised drivers as last fallback', () => {
    const out = assignBatch([
      { tripId: 'late', createdAt: t(5), candidates: [{ driverId: 'd1', etaMin: 2 }, { driverId: 'd3', etaMin: 6 }] },
      { tripId: 'early', createdAt: t(0), candidates: [{ driverId: 'd1', etaMin: 2 }] },
    ]);
    expect(out.get('early')).toEqual(['d1']);
    expect(out.get('late')).toEqual(['d3', 'd1']);
  });

  it('returns an empty queue when a trip has no candidates', () => {
    expect(assignBatch([{ tripId: 'A', createdAt: t(0), candidates: [] }]).get('A')).toEqual([]);
  });
});
