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
  readonly durationMin: number;
  readonly encodedPolyline: string;
  readonly points: LatLngLiteral[];
}

export type TravelMode = 'DRIVE' | 'TWO_WHEELER';

const TIMEOUT_MS = 5000;
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
    const url = `https://maps.googleapis.com/maps/api/geocode/json?latlng=${point.lat},${point.lng}&key=${this.env.googleMapsApiKey}`;
    const json = await this.call<{ status: string; results?: { place_id: string; formatted_address: string; address_components?: { long_name: string; types: string[] }[] }[] }>(
      url,
      { method: 'GET', isKeyInUrl: true },
    );
    const first = json?.status === 'OK' ? json.results?.[0] : undefined;
    if (!first) return null;
    const area = first.address_components?.find((c) => c.types.includes('sublocality') || c.types.includes('locality'));
    return { placeId: first.place_id, name: area?.long_name ?? first.formatted_address.split(',')[0], address: first.formatted_address, ...point };
  }

  /** Routes API computeRoutes (traffic-unaware = Essentials SKU). */
  async route(params: { from: LatLngLiteral; to: LatLngLiteral; mode: TravelMode }): Promise<RoadRoute | null> {
    const wp = (p: LatLngLiteral): object => ({ location: { latLng: { latitude: p.lat, longitude: p.lng } } });
    const json = await this.call<{ routes?: { distanceMeters?: number; duration?: string; polyline?: { encodedPolyline?: string } }[] }>(
      'https://routes.googleapis.com/directions/v2:computeRoutes',
      {
        method: 'POST',
        fieldMask: 'routes.distanceMeters,routes.duration,routes.polyline.encodedPolyline',
        body: JSON.stringify({ origin: wp(params.from), destination: wp(params.to), travelMode: params.mode, routingPreference: params.mode === 'DRIVE' ? 'TRAFFIC_UNAWARE' : undefined, regionCode: 'in' }),
      },
    );
    const r = json?.routes?.[0];
    if (!r?.distanceMeters || !r.polyline?.encodedPolyline) return null;
    const seconds = Number((r.duration ?? '0s').replace('s', ''));
    return {
      distanceKm: Math.round((r.distanceMeters / 1000) * 10) / 10,
      durationMin: Math.max(1, Math.round(seconds / 60)),
      encodedPolyline: r.polyline.encodedPolyline,
      points: decodePolyline(r.polyline.encodedPolyline),
    };
  }

  private async call<T>(url: string, opts: { method: 'GET' | 'POST'; body?: string; fieldMask?: string; isKeyInUrl?: boolean }): Promise<T | null> {
    if (!this.isEnabled) return null;
    const headers: Record<string, string> = { 'Content-Type': 'application/json' };
    if (!opts.isKeyInUrl) headers['X-Goog-Api-Key'] = this.env.googleMapsApiKey;
    if (opts.fieldMask) headers['X-Goog-FieldMask'] = opts.fieldMask;
    try {
      const res = await fetch(url, { method: opts.method, headers, body: opts.body, signal: AbortSignal.timeout(TIMEOUT_MS) });
      if (!res.ok) {
        this.logger.warn(`Google ${new URL(url).pathname} → ${res.status}`);
        return null;
      }
      return (await res.json()) as T;
    } catch (e) {
      this.logger.warn(`Google call failed: ${(e as Error).message}`);
      return null;
    }
  }
}
