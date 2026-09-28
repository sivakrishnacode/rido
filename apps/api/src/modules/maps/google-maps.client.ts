import { Inject, Injectable, Logger } from '@nestjs/common';

import type { Env } from '../../core/config/env.js';
import { ENV } from '../../core/config/env.token.js';
import { decodePolyline, LatLngLiteral } from './polyline.js';

/** One autocomplete suggestion (Places API New). */
export interface PlaceSuggestion {
  readonly placeId: string;
  readonly name: string;
  readonly address: string;
}

/** A resolved place with coordinates. */
export interface ResolvedPlace extends PlaceSuggestion, LatLngLiteral {}

/** A road route between two points. */
export interface RoadRoute {
  readonly distanceKm: number;
  /** Google's minutes: traffic-aware for fare routes (when fetched), traffic-unaware for ETAs. */
  readonly durationMin: number;
  readonly encodedPolyline: string;
  readonly points: LatLngLiteral[];
}

/** One route of a computeRoutes answer (only the fields we ask for). */
interface GoogleRoute {
  readonly distanceMeters?: number;
  readonly duration?: string;
  readonly polyline?: { encodedPolyline?: string };
  readonly routeLabels?: string[];
}

/** The shortest route with a path (the default and its alternates); a tie keeps Google's order (default first). */
export function shortestRoute(routes: readonly GoogleRoute[]): GoogleRoute | undefined {
  return routes
    .filter((r) => (r.distanceMeters ?? 0) > 0 && r.polyline?.encodedPolyline)
    .reduce<GoogleRoute | undefined>((best, r) => (!best || r.distanceMeters! < best.distanceMeters! ? r : best), undefined);
}

/**
 * Every route drives. TWO_WHEELER is beta (Google requires an in-app warning) and bills at Routes Enterprise (3×
 * Essentials, 7k free a month); bikes are priced on the car route anyway so the fare matches P-10.
 */
export type TravelMode = 'DRIVE';

const TIMEOUT_MS = 5000;
/** ETAs have fallbacks (learned speeds, estimate), so they give Google less time. */
const ETA_TIMEOUT_MS = 2500;
/** Bias results to Coimbatore (30 km). */
const BIAS = { latitude: 11.0168, longitude: 76.9658, radius: 30_000 } as const;

/**
 * Thin client for Google Maps Platform web services. Every call returns null on failure so callers
 * can fall back to local data. Requests only the fields we use (FieldMask) to stay on the cheaper SKUs.
 */
@Injectable()
export class GoogleMapsClient {
  private readonly logger = new Logger(GoogleMapsClient.name);

  constructor(@Inject(ENV) private readonly env: Env) {}

  get isEnabled(): boolean {
    return this.env.googleMapsApiKey.length > 0;
  }

  /** Places Autocomplete (New). Pass the same [sessionToken] until [placeDetails] ends the session. */
  async autocomplete(params: { input: string; sessionToken: string }): Promise<PlaceSuggestion[] | null> {
    const body = {
      input: params.input,
      sessionToken: params.sessionToken,
      includedRegionCodes: ['in'],
      locationBias: { circle: { center: { latitude: BIAS.latitude, longitude: BIAS.longitude }, radius: BIAS.radius } },
    };
    const json = await this.call<{ suggestions?: { placePrediction?: { placeId: string; structuredFormat?: { mainText?: { text: string }; secondaryText?: { text: string } } } }[] }>(
      'https://places.googleapis.com/v1/places:autocomplete',
      { method: 'POST', body: JSON.stringify(body) },
    );
    if (!json) return null;
    return (json.suggestions ?? [])
      .map((s) => s.placePrediction)
      .filter((p): p is NonNullable<typeof p> => !!p)
      .map((p) => ({ placeId: p.placeId, name: p.structuredFormat?.mainText?.text ?? '', address: p.structuredFormat?.secondaryText?.text ?? '' }));
  }

  /** Place Details (Essentials fields only); ends the autocomplete session. */
  async placeDetails(params: { placeId: string; sessionToken?: string }): Promise<ResolvedPlace | null> {
    const qs = params.sessionToken ? `?sessionToken=${encodeURIComponent(params.sessionToken)}` : '';
    const json = await this.call<{ id: string; displayName?: { text: string }; formattedAddress?: string; location?: { latitude: number; longitude: number } }>(
      `https://places.googleapis.com/v1/places/${encodeURIComponent(params.placeId)}${qs}`,
      // Essentials fields only (displayName would bill at Pro); the app keeps the suggestion's name.
      { method: 'GET', fieldMask: 'id,formattedAddress,location' },
    );
    if (!json?.location) return null;
    return {
      placeId: json.id,
      name: json.displayName?.text ?? (json.formattedAddress ?? '').split(',')[0].trim(),
      address: json.formattedAddress ?? '',
      lat: json.location.latitude,
      lng: json.location.longitude,
    };
  }

  /** Geocoding API reverse lookup. */
  async reverseGeocode(point: LatLngLiteral): Promise<ResolvedPlace | null> {
    const url = `https://maps.googleapis.com/maps/api/geocode/json?latlng=${point.lat},${point.lng}&language=en&key=${this.env.googleMapsApiKey}`;
    const json = await this.call<{ status: string; results?: { place_id: string; formatted_address: string; types?: string[]; address_components?: { long_name: string; types: string[] }[] }[] }>(
      url,
      { method: 'GET', isKeyInUrl: true },
    );
    // The first result can be a plus code ("7Q6M+2X Coimbatore") or an unnamed road: take the first real address.
    const results = json?.status === 'OK' ? (json.results ?? []) : [];
    const isReal = (r: (typeof results)[number]): boolean => !r.types?.includes('plus_code') && !/^unnamed road/i.test(r.formatted_address);
    const first = results.find(isReal) ?? results[0];
    if (!first) return null;
    const area = first.address_components?.find((c) => c.types.includes('sublocality') || c.types.includes('locality'));
    return { placeId: first.place_id, name: area?.long_name ?? first.formatted_address.split(',')[0], address: first.formatted_address, ...point };
  }

  /**
   * Routes API computeRoutes.
   *
   * `vehicleStopover` snaps a stop to a road where a vehicle can pull over, not a flyover or highway passing
   * above it: a drop pinned on the Ukkadam flyover was routed 16.5 km round via Podanur instead of 11.4 km along
   * Trichy Road. It bills the request at Routes Pro (Essentials without it), so only fare routes set [stops];
   * ETAs (cell centre to cell centre, often a moving driver) leave it off.
   *
   * Fare routes also ask for `computeAlternativeRoutes` (up to 3 alternates, no SKU change: Pro is already set by the
   * stopovers) and keep the **shortest** by `distanceMeters`: the fare is charged per km, so the map, the cached route
   * and the trip's `routePolyline` are the route the rider pays for (Google's default is the fastest).
   * Fare routes are `TRAFFIC_AWARE`, so their `durationMin` is Google's travel time now (display only: the fare's
   * minutes stay on the 18 km/h model).
   */
  async route(params: { from: LatLngLiteral; to: LatLngLiteral; mode: TravelMode; stops?: boolean }): Promise<RoadRoute | null> {
    const isEta = params.stops === false;
    const wp = (p: LatLngLiteral, isStop: boolean): object => ({
      location: { latLng: { latitude: p.lat, longitude: p.lng } },
      ...(isStop && { vehicleStopover: true }),
    });
    const json = await this.call<{ routes?: GoogleRoute[] }>(
      'https://routes.googleapis.com/directions/v2:computeRoutes',
      {
        method: 'POST',
        // An ETA needs no path (smaller answer, same SKU).
        fieldMask: isEta ? 'routes.distanceMeters,routes.duration' : 'routes.distanceMeters,routes.duration,routes.polyline.encodedPolyline,routes.routeLabels',
        timeoutMs: isEta ? ETA_TIMEOUT_MS : TIMEOUT_MS,
        body: JSON.stringify({
          origin: wp(params.from, !isEta),
          destination: wp(params.to, !isEta),
          travelMode: params.mode,
          // Fare routes are Pro already (stopovers), so traffic costs nothing more there; ETAs stay Essentials.
          // Never TRAFFIC_AWARE_OPTIMAL (Enterprise-priced in some regions, and slower).
          routingPreference: isEta ? 'TRAFFIC_UNAWARE' : 'TRAFFIC_AWARE',
          ...(!isEta && { computeAlternativeRoutes: true }),
          regionCode: 'in',
        }),
      },
    );
    const r = isEta ? json?.routes?.[0] : shortestRoute(json?.routes ?? []);
    const encoded = r?.polyline?.encodedPolyline ?? '';
    if (!r?.distanceMeters || (!isEta && !encoded)) return null;
    const seconds = Number((r.duration ?? '0s').replace('s', ''));
    return {
      distanceKm: Math.round((r.distanceMeters / 1000) * 10) / 10,
      durationMin: Math.max(1, Math.round(seconds / 60)),
      encodedPolyline: encoded,
      points: encoded ? decodePolyline(encoded) : [],
    };
  }

  private async call<T>(url: string, opts: { method: 'GET' | 'POST'; body?: string; fieldMask?: string; isKeyInUrl?: boolean; timeoutMs?: number }): Promise<T | null> {
    if (!this.isEnabled) return null;
    const headers: Record<string, string> = { 'Content-Type': 'application/json' };
    if (!opts.isKeyInUrl) headers['X-Goog-Api-Key'] = this.env.googleMapsApiKey;
    if (opts.fieldMask) headers['X-Goog-FieldMask'] = opts.fieldMask;
    try {
      const res = await fetch(url, { method: opts.method, headers, body: opts.body, signal: AbortSignal.timeout(opts.timeoutMs ?? TIMEOUT_MS) });
      if (!res.ok) {
        // 429 = quota / rate limit: callers fall back to local estimates.
        this.logger.warn(`Google ${new URL(url).pathname} → ${res.status}${res.status === 429 ? ' (quota exceeded)' : ''}`);
        return null;
      }
      return (await res.json()) as T;
    } catch (e) {
      this.logger.warn(`Google call failed: ${(e as Error).message}`);
      return null;
    }
  }
}
