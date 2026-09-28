import type { Env } from '../../core/config/env.js';
import { GoogleMapsClient, shortestRoute } from './google-maps.client.js';

const from = { lat: 10.98085, lng: 77.04175 };
const ukkadamFlyover = { lat: 10.98833, lng: 76.96269 };

/** Captures the computeRoutes request body. */
function stubFetch(answer: unknown = null): { bodies: Record<string, unknown>[]; urls: string[] } {
  const bodies: Record<string, unknown>[] = [];
  const urls: string[] = [];
  vi.stubGlobal(
    'fetch',
    vi.fn(async (url: string, init: { body?: string; headers: Record<string, string> }) => {
      urls.push(url);
      if (init.body) bodies.push({ ...(JSON.parse(init.body) as Record<string, unknown>), fieldMask: init.headers['X-Goog-FieldMask'] });
      return new Response(JSON.stringify(answer ?? { routes: [{ distanceMeters: 11439, duration: '1507s', polyline: { encodedPolyline: '_p~iF~ps|U' } }] }));
    }),
  );
  return { bodies, urls };
}

describe('GoogleMapsClient.route', () => {
  afterEach(() => vi.unstubAllGlobals());
  const client = new GoogleMapsClient({ googleMapsApiKey: 'test-key' } as unknown as Env);

  it('marks pickup and drop as vehicle stopovers, so a pin on a flyover is routed from the street below', async () => {
    const { bodies } = stubFetch();
    const r = await client.route({ from, to: ukkadamFlyover, mode: 'DRIVE' });
    expect(r?.distanceKm).toBe(11.4);
    expect(bodies[0]).toMatchObject({ origin: { vehicleStopover: true }, destination: { vehicleStopover: true } });
  });

  it('ETAs send no stopover (keeps them on the cheaper Essentials tier)', async () => {
    const { bodies } = stubFetch();
    await client.route({ from, to: ukkadamFlyover, mode: 'DRIVE', stops: false });
    expect((bodies[0].origin as Record<string, unknown>).vehicleStopover).toBeUndefined();
    expect((bodies[0].destination as Record<string, unknown>).vehicleStopover).toBeUndefined();
  });

  it('asks an ETA for distance and time only, and returns it without a path', async () => {
    const { bodies } = stubFetch({ routes: [{ distanceMeters: 5200, duration: '780s' }] });
    const r = await client.route({ from, to: ukkadamFlyover, mode: 'DRIVE', stops: false });
    expect(bodies[0].fieldMask).toBe('routes.distanceMeters,routes.duration');
    expect(r).toMatchObject({ distanceKm: 5.2, durationMin: 13, points: [] });
  });

  it('asks a fare route for alternatives and keeps the shortest, with its path', async () => {
    const { bodies } = stubFetch({
      routes: [
        { distanceMeters: 16500, duration: '1500s', polyline: { encodedPolyline: 'fastest' }, routeLabels: ['DEFAULT_ROUTE'] },
        { distanceMeters: 11425, duration: '1900s', polyline: { encodedPolyline: '_p~iF~ps|U' }, routeLabels: ['DEFAULT_ROUTE_ALTERNATE'] },
        { distanceMeters: 13100, duration: '1700s', polyline: { encodedPolyline: 'middle' }, routeLabels: ['DEFAULT_ROUTE_ALTERNATE'] },
      ],
    });
    const r = await client.route({ from, to: ukkadamFlyover, mode: 'DRIVE' });
    expect(bodies[0]).toMatchObject({ computeAlternativeRoutes: true });
    expect(bodies[0].fieldMask).toContain('routes.routeLabels');
    expect(r).toMatchObject({ distanceKm: 11.4, durationMin: 32, encodedPolyline: '_p~iF~ps|U' });
  });

  it('ETAs ask for no alternatives', async () => {
    const { bodies } = stubFetch({ routes: [{ distanceMeters: 5200, duration: '780s' }] });
    await client.route({ from, to: ukkadamFlyover, mode: 'DRIVE', stops: false });
    expect(bodies[0].computeAlternativeRoutes).toBeUndefined();
  });

  it('a fare route without a path is no route', async () => {
    stubFetch({ routes: [{ distanceMeters: 5200, duration: '780s' }] });
    expect(await client.route({ from, to: ukkadamFlyover, mode: 'DRIVE' })).toBeNull();
  });
});

describe('GoogleMapsClient.reverseGeocode', () => {
  afterEach(() => vi.unstubAllGlobals());
  const client = new GoogleMapsClient({ googleMapsApiKey: 'test-key' } as unknown as Env);

  it('skips a plus code and an unnamed road for the first real address, in English', async () => {
    const { urls } = stubFetch({
      status: 'OK',
      results: [
        { place_id: 'pc', formatted_address: 'XWJ2+8R Coimbatore, Tamil Nadu', types: ['plus_code'] },
        { place_id: 'ur', formatted_address: 'Unnamed Road, Ondipudur, Coimbatore', types: ['route'] },
        {
          place_id: 'real',
          formatted_address: 'Trichy Rd, Ondipudur, Coimbatore, Tamil Nadu 641016',
          types: ['street_address'],
          address_components: [{ long_name: 'Ondipudur', types: ['sublocality', 'political'] }],
        },
      ],
    });
    const p = await client.reverseGeocode(from);
    expect(p).toMatchObject({ placeId: 'real', name: 'Ondipudur' });
    expect(urls[0]).toContain('language=en');
  });
});

describe('shortestRoute', () => {
  const r = (m: number, p = 'x'): { distanceMeters: number; polyline: { encodedPolyline: string } } => ({ distanceMeters: m, polyline: { encodedPolyline: p } });

  it('picks the shortest of three routes', () => {
    expect(shortestRoute([r(16500, 'a'), r(11400, 'b'), r(13000, 'c')])?.polyline?.encodedPolyline).toBe('b');
  });

  it('skips a route without a path and keeps the default on a tie', () => {
    expect(shortestRoute([r(9000, 'default'), { distanceMeters: 5000 }, r(9000, 'alt')])?.polyline?.encodedPolyline).toBe('default');
    expect(shortestRoute([])).toBeUndefined();
  });
});
