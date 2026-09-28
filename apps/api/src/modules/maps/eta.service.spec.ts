import type { RedisService } from '../../core/redis/redis.service.js';
import { VehicleKind } from '../../generated/prisma/enums.js';
import type { HexStatsService } from '../geo/hex-stats.service.js';
import type { SettingsService } from '../settings/settings.service.js';
import { EtaService } from './eta.service.js';
import type { MapsService } from './maps.service.js';
import { MapsService as Maps } from './maps.service.js';

function fakeRedis(): RedisService {
  const store = new Map<string, string>();
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
});
