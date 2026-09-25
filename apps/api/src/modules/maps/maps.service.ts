import { Injectable } from '@nestjs/common';

import { RedisService } from '../../core/redis/redis.service.js';
import { VehicleKind } from '../../generated/prisma/enums.js';
import { estimateRoute, GeoPoint } from '../fares/fare-engine.js';
import { GoogleMapsClient, PlaceSuggestion, ResolvedPlace, RoadRoute, TravelMode } from './google-maps.client.js';
import type { LatLngLiteral } from './polyline.js';

const DAY_S = 86_400;
const TTL = { autocomplete: DAY_S, details: 30 * DAY_S, geocode: 30 * DAY_S, route: 6 * 3600 } as const;

/**
 * Google Maps Platform with Redis caching (the biggest cost lever), and a local fallback
 * (seeded places + haversine × 1.3) when no key is configured or Google fails.
 */
@Injectable()
export class MapsService {
  constructor(
    private readonly google: GoogleMapsClient,
    private readonly redis: RedisService,
  ) {}

  get isGoogleEnabled(): boolean {
    return this.google.isEnabled;
  }

  async autocomplete(params: { input: string; sessionToken: string }): Promise<PlaceSuggestion[] | null> {
    const input = params.input.trim().toLowerCase();
    if (input.length < 3) return [];
    return this.cached(`maps:ac:${input}`, TTL.autocomplete, () => this.google.autocomplete({ ...params, input }));
  }

  details(params: { placeId: string; sessionToken?: string }): Promise<ResolvedPlace | null> {
    return this.cached(`maps:pd:${params.placeId}`, TTL.details, () => this.google.placeDetails(params));
  }

  reverseGeocode(point: LatLngLiteral): Promise<ResolvedPlace | null> {
    // ~11 m grid so nearby pins share a cache entry.
    const key = `maps:rg:${point.lat.toFixed(4)},${point.lng.toFixed(4)}`;
    return this.cached(key, TTL.geocode, () => this.google.reverseGeocode(point));
  }

  /** Road route (Google when enabled; cached ~6 h on a ~100 m grid), else null. */
  route(params: { from: LatLngLiteral; to: LatLngLiteral; vehicleKind?: VehicleKind }): Promise<RoadRoute | null> {
    const mode: TravelMode = params.vehicleKind === VehicleKind.BIKE || params.vehicleKind === VehicleKind.GOODS_BIKE ? 'TWO_WHEELER' : 'DRIVE';
    const g = (p: LatLngLiteral): string => `${p.lat.toFixed(3)},${p.lng.toFixed(3)}`;
    return this.cached(`maps:rt:${mode}:${g(params.from)}:${g(params.to)}`, TTL.route, () => this.google.route({ ...params, mode }));
  }

  /** Distance/duration for fares: measured demo routes first, then Google road distance, then haversine × 1.3. */
  async estimate(params: { from: GeoPoint; to: GeoPoint; vehicleKind?: VehicleKind }): Promise<{ distanceKm: number; durationMin: number }> {
    const local = estimateRoute(params.from, params.to);
    if (!this.isGoogleEnabled || this.isDemo(params.from, params.to)) return local;
    const road = await this.route(params);
    if (!road) return local;
    // Real road distance from Google; duration keeps the 18 km/h fare model so prices stay predictable.
    return { distanceKm: road.distanceKm, durationMin: Math.max(1, Math.round((road.distanceKm / 18) * 60)) };
  }

  /** True when the pair is one of the measured demo routes (keeps design fares stable). */
  private isDemo(from: GeoPoint, to: GeoPoint): boolean {
    const a = estimateRoute(from, to);
    const b = estimateRoute({ lat: from.lat, lng: from.lng }, { lat: to.lat, lng: to.lng });
    return a.distanceKm !== b.distanceKm;
  }

  private async cached<T>(key: string, ttl: number, load: () => Promise<T | null>): Promise<T | null> {
    const hit = await this.redis.get(key);
    if (hit) return JSON.parse(hit) as T;
    const value = await load();
    if (value !== null) await this.redis.set(key, JSON.stringify(value), 'EX', ttl);
    return value;
  }
}
