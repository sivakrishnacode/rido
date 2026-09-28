import type { RedisService } from '../../core/redis/redis.service.js';
import { VehicleKind } from '../../generated/prisma/enums.js';
import type { HexStatsService } from '../geo/hex-stats.service.js';
import type { SettingsService } from '../settings/settings.service.js';
import { EtaService } from './eta.service.js';
import type { MapsService } from './maps.service.js';
import { MapsService as Maps } from './maps.service.js';

function fakeRedis(store = new Map<string, string>()): RedisService {
  return {
    get: async (k: string) => store.get(k) ?? null,
    set: async (k: string, v: string) => (store.set(k, v), 'OK'),
  } as unknown as RedisService;
}

describe('EtaService', () => {
  it('caches road ETAs per cell pair and travel mode, without a stopover (Routes Essentials)', async () => {
    const route = vi.fn(async (_p: { stops?: boolean }) => ({ durationMin: 14 }));
    const maps = { isGoogleEnabled: true, route } as unknown as MapsService;
    const settings = { get: vi.fn(async () => 0) } as unknown as SettingsService;
    const eta = new EtaService(maps, fakeRedis(), {} as HexStatsService, settings);
    const from = { lat: 11.0183, lng: 76.9725 };
    const to = { lat: 10.9545, lng: 77.0076 };
    expect(await eta.minutes({ from, to, vehicleKind: VehicleKind.BIKE, useRoad: true })).toBe(14);
    expect(await eta.minutes({ from, to, vehicleKind: VehicleKind.CAB, useRoad: true })).toBe(14);
    expect(await eta.minutes({ from, to, vehicleKind: VehicleKind.AUTO, useRoad: true })).toBe(14);
    // Every vehicle drives: one Google call serves them all for 10 minutes.
    expect(route).toHaveBeenCalledTimes(1);
    expect(route.mock.calls.every((c) => (c[0] as { stops?: boolean }).stops === false)).toBe(true);
    expect(Maps.travelMode(VehicleKind.BIKE)).toBe('DRIVE');
  });

  describe('minutesMany', () => {
    const pickup = { lat: 10.98085, lng: 77.04175 };
    const gandhipuram = { lat: 11.0183, lng: 76.9725 };
    const vellalore = { lat: 10.9545, lng: 77.0076 };
    const peelamedu = { lat: 11.0247, lng: 77.0028 };
    const settings = { get: vi.fn(async () => 0) } as unknown as SettingsService;

    function setup(legs: ({ durationMin: number } | null)[] | null): { eta: EtaService; etaMatrix: ReturnType<typeof vi.fn>; route: ReturnType<typeof vi.fn>; store: Map<string, string> } {
      const store = new Map<string, string>();
      const etaMatrix = vi.fn(async (p: { origins: unknown[] }) => (legs ? legs.slice(0, p.origins.length) : null));
      const route = vi.fn();
      const maps = { isGoogleEnabled: true, etaMatrix, route } as unknown as MapsService;
      return { eta: new EtaService(maps, fakeRedis(store), {} as HexStatsService, settings), etaMatrix, route, store };
    }

    it('one matrix call for all the misses, each written to the per-cell-pair cache', async () => {
      const { eta, etaMatrix, route, store } = setup([{ durationMin: 29 }, { durationMin: 19 }, { durationMin: 12 }]);
      const mins = await eta.minutesMany({ froms: [gandhipuram, vellalore, peelamedu, gandhipuram], to: pickup, useRoad: true });
      expect(mins).toEqual([29, 19, 12, 29]);
      // Two drivers in one cell share one origin.
      expect(etaMatrix).toHaveBeenCalledTimes(1);
      expect((etaMatrix.mock.calls[0][0] as { origins: unknown[] }).origins).toHaveLength(3);
      expect(route).not.toHaveBeenCalled();
      expect([...store.keys()].filter((k) => k.startsWith('eta:road:DRIVE:'))).toHaveLength(3);
      // The single-driver lookup reads the same cache.
      expect(await eta.minutes({ from: vellalore, to: pickup, useRoad: true })).toBe(19);
      expect(route).not.toHaveBeenCalled();
    });

    it('cache hits skip the call; only the missing cell is asked for', async () => {
      const { eta, etaMatrix } = setup([{ durationMin: 12 }]);
      await eta.minutesMany({ froms: [gandhipuram], to: pickup, useRoad: true });
      await eta.minutesMany({ froms: [gandhipuram], to: pickup, useRoad: true });
      expect(etaMatrix).toHaveBeenCalledTimes(1);
      await eta.minutesMany({ froms: [gandhipuram, peelamedu], to: pickup, useRoad: true });
      expect(etaMatrix).toHaveBeenCalledTimes(2);
      expect((etaMatrix.mock.calls[1][0] as { origins: unknown[] }).origins).toHaveLength(1);
    });

    it('an element Google could not route, or a failed call, falls back to the estimate', async () => {
      const { eta } = setup([{ durationMin: 29 }, null]);
      const [a, b] = await eta.minutesMany({ froms: [gandhipuram, vellalore], to: pickup, useRoad: true });
      expect(a).toBe(29);
      expect(b).toBeGreaterThan(1);
      const failed = setup(null);
      expect((await failed.eta.minutesMany({ froms: [gandhipuram], to: pickup, useRoad: true }))[0]).toBeGreaterThan(1);
    });

    it('same cell as the pickup is 1 minute, no call; useRoad off never calls Google', async () => {
      const { eta, etaMatrix } = setup([{ durationMin: 5 }]);
      expect(await eta.minutesMany({ froms: [pickup], to: pickup, useRoad: true })).toEqual([1]);
      await eta.minutesMany({ froms: [gandhipuram], to: pickup, useRoad: false });
      expect(etaMatrix).not.toHaveBeenCalled();
    });
  });
});
