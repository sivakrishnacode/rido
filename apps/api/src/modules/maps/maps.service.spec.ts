import type { RedisService } from '../../core/redis/redis.service.js';
import type { GoogleMapsClient, RoadRoute } from './google-maps.client.js';
import { MapsService } from './maps.service.js';

/** In-memory stand-in for the Redis commands MapsService uses. */
function fakeRedis(): RedisService {
  const store = new Map<string, string>();
  return {
    get: async (k: string) => store.get(k) ?? null,
    set: async (k: string, v: string) => {
      store.set(k, v);
      return 'OK';
    },
  } as unknown as RedisService;
}

const road: RoadRoute = { distanceKm: 9.1, durationMin: 20, encodedPolyline: 'abc', points: [] };
const gandhipuram = { lat: 11.0183, lng: 76.9725, placeId: 'gandhipuram' };
const brookefields = { lat: 11.009, lng: 76.96, placeId: 'brookefields' };
const vellalore = { lat: 10.9545, lng: 77.0076 };

describe('MapsService', () => {
  it('uses the local estimate when Google is off', async () => {
    const google = { isEnabled: false, route: vi.fn() } as unknown as GoogleMapsClient;
    const maps = new MapsService(google, fakeRedis());
    const est = await maps.estimate({ from: gandhipuram, to: vellalore });
    expect(est.distanceKm).toBeGreaterThan(5);
    expect(google.route).not.toHaveBeenCalled();
  });

  it('keeps measured demo routes even when Google is on', async () => {
    const google = { isEnabled: true, route: vi.fn(async () => road) } as unknown as GoogleMapsClient;
    const maps = new MapsService(google, fakeRedis());
    expect(await maps.estimate({ from: gandhipuram, to: brookefields })).toEqual({ distanceKm: 4.2, durationMin: 14 });
  });

  it('uses the Google road distance and caches the route', async () => {
    const route = vi.fn(async () => road);
    const maps = new MapsService({ isEnabled: true, route } as unknown as GoogleMapsClient, fakeRedis());
    const first = await maps.estimate({ from: gandhipuram, to: vellalore });
    await maps.estimate({ from: gandhipuram, to: vellalore });
    expect(first).toEqual({ distanceKm: 9.1, durationMin: 30 });
    expect(route).toHaveBeenCalledTimes(1);
  });
});
