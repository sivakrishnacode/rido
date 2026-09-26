import { HexStatsService, istHour } from './hex-stats.service.js';
import { cellAt } from './h3.util.js';

describe('istHour', () => {
  it('converts UTC to IST (+5:30)', () => {
    expect(istHour(new Date('2026-09-25T02:29:00Z'))).toBe(7);
    expect(istHour(new Date('2026-09-25T02:30:00Z'))).toBe(8);
    expect(istHour(new Date('2026-09-25T20:00:00Z'))).toBe(1);
  });
});

describe('HexStatsService backoff', () => {
  const at = { lat: 11.0183, lng: 76.9725 }; // Gandhipuram
  const to = { lat: 11.029, lng: 77.027 }; // Peelamedu
  const row = (res: 7 | 8 | 9, hour: number, trips: number, kmh: number, minutes = 20) => ({
    fromCell: cellAt(at.lat, at.lng, res), toCell: cellAt(to.lat, to.lng, res), res, hour, trips, avgSpeedKmh: kmh, avgDurationMin: minutes,
  });
  const service = async (rows: ReturnType<typeof row>[]) => {
    const s = new HexStatsService({ hexStat: { findMany: vi.fn().mockResolvedValue(rows) } } as never, {} as never);
    await s.load();
    return s;
  };

  it('uses the finest resolution with enough trips at the exact hour', async () => {
    const s = await service([row(9, 9, 2, 10), row(8, 9, 6, 12), row(7, 9, 40, 18)]);
    expect(s.speedKmh({ from: at, to, hour: 9, minTrips: 5 })).toMatchObject({ res: 8, hour: 9, speed: 12 });
    expect(s.speedKmh({ from: at, to, hour: 9, minTrips: 1 })).toMatchObject({ res: 9, hour: 9, speed: 10 });
  });

  it('prefers a coarser pair at the exact hour over an all-hours average', async () => {
    const s = await service([row(9, 18, 30, 25), row(7, 9, 8, 13)]);
    expect(s.speedKmh({ from: at, to, hour: 9, minTrips: 5 })).toMatchObject({ res: 7, hour: 9, speed: 13 });
  });

  it('falls back to the all-hours average as total km / total time', async () => {
    // 10 trips × 30 min at 12 km/h (60 km, 5 h) + 10 trips × 10 min at 30 km/h (50 km, 1.67 h) = 110 km / 6.67 h.
    const s = await service([row(9, 8, 10, 12, 30), row(9, 14, 10, 30, 10)]);
    const hit = s.speedKmh({ from: at, to, hour: 3, minTrips: 5 });
    expect(hit).toMatchObject({ res: 9, hour: '*', trips: 20 });
    expect(hit!.speed).toBeCloseTo(16.5, 1);
  });

  it('returns null when no pair has enough trips', async () => {
    const s = await service([row(7, 9, 2, 13)]);
    expect(s.speedKmh({ from: at, to, hour: 9, minTrips: 5 })).toBeNull();
  });
});
