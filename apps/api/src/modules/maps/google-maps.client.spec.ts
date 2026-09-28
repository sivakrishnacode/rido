import type { Env } from '../../core/config/env.js';
import { GoogleMapsClient } from './google-maps.client.js';

const from = { lat: 10.98085, lng: 77.04175 };
const ukkadamFlyover = { lat: 10.98833, lng: 76.96269 };

/** Captures the computeRoutes request body. */
function stubFetch(): { bodies: Record<string, unknown>[] } {
  const bodies: Record<string, unknown>[] = [];
  vi.stubGlobal(
    'fetch',
    vi.fn(async (_url: string, init: { body: string }) => {
      bodies.push(JSON.parse(init.body) as Record<string, unknown>);
      return new Response(JSON.stringify({ routes: [{ distanceMeters: 11439, duration: '1507s', polyline: { encodedPolyline: '_p~iF~ps|U' } }] }));
    }),
  );
  return { bodies };
}

describe('GoogleMapsClient.route', () => {
  afterEach(() => vi.unstubAllGlobals());
  const client = new GoogleMapsClient({ googleMapsApiKey: 'test-key' } as unknown as Env);

  it('marks pickup and drop as vehicle stopovers, so a pin on a flyover is routed from the street below', async () => {
    const { bodies } = stubFetch();
    const r = await client.route({ from, to: ukkadamFlyover, mode: 'TWO_WHEELER' });
    expect(r?.distanceKm).toBe(11.4);
    expect(bodies[0]).toMatchObject({ origin: { vehicleStopover: true }, destination: { vehicleStopover: true } });
  });

  it('leaves a moving driver where they are (ETA origin), still snapping the pickup', async () => {
    const { bodies } = stubFetch();
    await client.route({ from, to: ukkadamFlyover, mode: 'DRIVE', fromIsStop: false });
    expect((bodies[0].origin as Record<string, unknown>).vehicleStopover).toBeUndefined();
    expect(bodies[0]).toMatchObject({ destination: { vehicleStopover: true } });
  });
});
