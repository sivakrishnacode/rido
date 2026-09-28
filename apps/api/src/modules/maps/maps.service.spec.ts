import type { RedisService } from '../../core/redis/redis.service.js';
import type { GoogleMapsClient, RoadRoute } from './google-maps.client.js';
import { MapsService } from './maps.service.js';

/** In-memory stand-in for the Redis commands MapsService uses ([store] lets a test expire keys). */
function fakeRedis(store = new Map<string, string>()): RedisService {
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
    expect(await maps.estimate({ from: gandhipuram, to: brookefields })).toEqual({ distanceKm: 4.2, durationMin: 14, travelMin: null });
  });

  it('uses the Google road distance and caches the route', async () => {
    const route = vi.fn(async () => road);
    const maps = new MapsService({ isEnabled: true, route } as unknown as GoogleMapsClient, fakeRedis());
    const first = await maps.estimate({ from: gandhipuram, to: vellalore });
    await maps.estimate({ from: gandhipuram, to: vellalore });
    expect(first).toEqual({ distanceKm: 9.1, durationMin: 30, travelMin: 20 });
    expect(route).toHaveBeenCalledTimes(1);
  });

  it("keeps the fare on 18 km/h but shows Google's traffic minutes, refreshed after 15 min without re-routing", async () => {
    const store = new Map<string, string>();
    const route = vi.fn(async () => road).mockResolvedValueOnce(road).mockResolvedValueOnce({ ...road, distanceKm: 9.4, durationMin: 27 });
    const maps = new MapsService({ isEnabled: true, route } as unknown as GoogleMapsClient, fakeRedis(store));
    expect(await maps.estimate({ from: gandhipuram, to: vellalore })).toEqual({ distanceKm: 9.1, durationMin: 30, travelMin: 20 });
    // Within 15 min: no call. The traffic key expires first (15 min vs the route's 6 h).
    await maps.estimate({ from: gandhipuram, to: vellalore });
    expect(route).toHaveBeenCalledTimes(1);
    for (const k of store.keys()) if (k.startsWith('maps:tt:')) store.delete(k);
    // One refresh for the minutes; distance (and so the fare) stays on the cached route.
    expect(await maps.estimate({ from: gandhipuram, to: vellalore })).toEqual({ distanceKm: 9.1, durationMin: 30, travelMin: 27 });
    expect(route).toHaveBeenCalledTimes(2);
    expect(await maps.cachedTravelMin({ from: gandhipuram, to: vellalore })).toBe(27);
  });

  it('cachedRoute reads the route the quote fetched and never calls Google', async () => {
    const route = vi.fn(async () => ({ ...road, encodedPolyline: 'route-from-quote' }));
    const maps = new MapsService({ isEnabled: true, route } as unknown as GoogleMapsClient, fakeRedis());
    expect(await maps.cachedRoute({ from: gandhipuram, to: vellalore })).toBeNull();
    await maps.estimate({ from: gandhipuram, to: vellalore });
    expect((await maps.cachedRoute({ from: gandhipuram, to: vellalore }))?.encodedPolyline).toBe('route-from-quote');
    // Every vehicle drives, so a bike's trip reads the same route.
    expect((await maps.cachedRoute({ from: gandhipuram, to: vellalore, vehicleKind: 'BIKE' }))?.encodedPolyline).toBe('route-from-quote');
    expect(route).toHaveBeenCalledTimes(1);
  });

  it('never caches Places content (only place IDs may be stored): each call asks Google', async () => {
    const autocomplete = vi.fn(async () => [{ placeId: 'p1', name: 'Ukkadam', address: 'Coimbatore' }]);
    const placeDetails = vi.fn(async () => ({ placeId: 'p1', name: 'Ukkadam', address: 'Coimbatore', lat: 10.99, lng: 76.96 }));
    const maps = new MapsService({ isEnabled: true, autocomplete, placeDetails } as unknown as GoogleMapsClient, fakeRedis());
    await maps.autocomplete({ input: 'Ukkadam', sessionToken: 's' });
    await maps.autocomplete({ input: 'Ukkadam', sessionToken: 's' });
    await maps.details({ placeId: 'p1', sessionToken: 's' });
    await maps.details({ placeId: 'p1', sessionToken: 's' });
    expect(autocomplete).toHaveBeenCalledTimes(2);
    expect(placeDetails).toHaveBeenCalledTimes(2);
  });
});
