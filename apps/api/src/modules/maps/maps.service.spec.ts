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
    del: async (...keys: string[]) => keys.filter((k) => store.delete(k)).length,
    multi() {
      const ops: (() => unknown)[] = [];
      const chain = {
        set: (k: string, v: string) => (ops.push(() => store.set(k, v)), chain),
        incr: (k: string) => (ops.push(() => store.set(k, String(Number(store.get(k) ?? 0) + 1))), chain),
        expire: () => chain,
        exec: async () => ops.map((op) => [null, op()]),
      };
      return chain;
    },
  } as unknown as RedisService;
}

const road: RoadRoute = { distanceKm: 9.1, durationMin: 20, encodedPolyline: 'abc', points: [] };
const gandhipuram = { lat: 11.0183, lng: 76.9725, placeId: 'gandhipuram' };
const brookefields = { lat: 11.009, lng: 76.96, placeId: 'brookefields' };
const vellalore = { lat: 10.9545, lng: 77.0076 };

/** Any service-area rectangle (cities come from the database). */
const AREA = { low: { lat: 10.75, lng: 76.69 }, high: { lat: 11.29, lng: 77.24 } };

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

  it('caches the reverse geocode with its landmark (30 d), so a second pin in the square costs nothing', async () => {
    const reverseGeocode = vi.fn(async () => ({ placeId: 'u', name: 'Ukkadam', address: 'Coimbatore', landmark: 'Near Ukkadam Bus stand', lat: 10.98833, lng: 76.96269 }));
    const maps = new MapsService({ isEnabled: true, reverseGeocode } as unknown as GoogleMapsClient, fakeRedis());
    await maps.reverseGeocode({ lat: 10.98833, lng: 76.96269 });
    expect((await maps.reverseGeocode({ lat: 10.98834, lng: 76.96271 }))?.landmark).toBe('Near Ukkadam Bus stand');
    expect(reverseGeocode).toHaveBeenCalledTimes(1);
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

  it('answers [] to fewer than 4 characters without asking Google', async () => {
    const autocomplete = vi.fn(async () => []);
    const maps = new MapsService({ isEnabled: true, autocomplete } as unknown as GoogleMapsClient, fakeRedis());
    expect(await maps.autocomplete({ input: '  Ukk  ', sessionToken: 's', restriction: AREA })).toEqual([]);
    expect(await maps.autocomplete({ input: 'gan', sessionToken: 's' })).toEqual([]);
    expect(autocomplete).not.toHaveBeenCalled();
  });

  it('keys autocomplete by normalised input, area and a ~1 km origin, never by user or session', () => {
    const key = MapsService.autocompleteKey({ input: '  Ukkadam   Bus  Stand ', restriction: AREA, origin: { lat: 10.98833, lng: 76.96269 } });
    expect(key).toBe('maps:ac1:10.750,76.690,11.290,77.240:10.99,76.96:ukkadam bus stand');
    // Same search a few hundred metres away, typed differently: the same entry.
    expect(MapsService.autocompleteKey({ input: 'ukkadam bus stand', restriction: AREA, origin: { lat: 10.9871, lng: 76.9612 } })).toBe(key);
    expect(MapsService.autocompleteKey({ input: 'ukkadam bus stand', restriction: null })).toBe('maps:ac1:any:none:ukkadam bus stand');
    expect(MapsService.autocompleteKey({ input: 'ukkadam bus stand', restriction: AREA, origin: { lat: 11.02, lng: 76.96 } })).not.toBe(key);
  });

  it('caches autocomplete answers for a day, passing the session token on a miss', async () => {
    const store = new Map<string, string>();
    const autocomplete = vi.fn(async () => [{ placeId: 'p1', name: 'Ukkadam', address: 'Coimbatore', distanceKm: 2.1 }]);
    const maps = new MapsService({ isEnabled: true, autocomplete } as unknown as GoogleMapsClient, fakeRedis(store));
    await maps.autocomplete({ input: 'Ukkadam', sessionToken: 's1', restriction: AREA });
    expect(await maps.autocomplete({ input: ' ukkadam ', sessionToken: 's2', restriction: AREA })).toEqual([{ placeId: 'p1', name: 'Ukkadam', address: 'Coimbatore', distanceKm: 2.1 }]);
    expect(autocomplete).toHaveBeenCalledTimes(1);
    expect(autocomplete).toHaveBeenCalledWith(expect.objectContaining({ input: 'ukkadam', sessionToken: 's1' }));
    expect(store.get('maps:acs:s1')).toBe('1'); // one billed call in session s1, none in s2
    expect(store.has('maps:acs:s2')).toBe(false);
  });

  it('serves a cached place unless the session made several billed autocomplete calls (Place Details then makes them free)', async () => {
    const store = new Map<string, string>();
    const place = { placeId: 'p1', name: 'Ukkadam', address: 'Coimbatore', lat: 10.99, lng: 76.96 };
    const autocomplete = vi.fn(async (p: { input: string }) => [{ placeId: 'p1', name: p.input, address: '' }]);
    const placeDetails = vi.fn(async () => place);
    const maps = new MapsService({ isEnabled: true, autocomplete, placeDetails } as unknown as GoogleMapsClient, fakeRedis(store));
    expect(await maps.details({ placeId: 'p1', sessionToken: 'a' })).toEqual(place);
    // A session with one billed keystroke: the cache is cheaper.
    await maps.autocomplete({ input: 'ukka', sessionToken: 'b' });
    expect(await maps.details({ placeId: 'p1', sessionToken: 'b' })).toEqual(place);
    expect(placeDetails).toHaveBeenCalledTimes(1);
    // Two billed keystrokes: Place Details ends the session (and refreshes the cache).
    await maps.autocomplete({ input: 'ukkad', sessionToken: 'c' });
    await maps.autocomplete({ input: 'ukkada', sessionToken: 'c' });
    expect(await maps.details({ placeId: 'p1', sessionToken: 'c' })).toEqual(place);
    expect(placeDetails).toHaveBeenCalledTimes(2);
    expect(store.has('maps:acs:c')).toBe(false);
  });

  it('falls back to the cached place when Google fails', async () => {
    const store = new Map<string, string>([['maps:pd1:p1', JSON.stringify({ placeId: 'p1', name: 'Ukkadam', address: '', lat: 10.99, lng: 76.96 })], ['maps:acs:s', '3']]);
    const maps = new MapsService({ isEnabled: true, placeDetails: vi.fn(async () => null) } as unknown as GoogleMapsClient, fakeRedis(store));
    expect((await maps.details({ placeId: 'p1', sessionToken: 's' }))?.lat).toBe(10.99);
  });
});
