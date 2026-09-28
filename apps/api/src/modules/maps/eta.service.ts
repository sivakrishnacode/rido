import { Injectable } from '@nestjs/common';
import { cellToLatLng } from 'h3-js';

import { RedisService } from '../../core/redis/redis.service.js';
import type { VehicleKind } from '../../generated/prisma/enums.js';
import { etaMinutes, FALLBACK_KMH, roadKm } from '../geo/eta-model.js';
import { cellAt } from '../geo/h3.util.js';
import { HexStatsService, istHour } from '../geo/hex-stats.service.js';
import { SettingsService } from '../settings/settings.service.js';
import { MATRIX_MAX_ORIGINS } from './google-maps.client.js';
import { MapsService } from './maps.service.js';

type Point = { readonly lat: number; readonly lng: number };

/**
 * ETAs for [items] (same order), one [EtaService.minutesMany] call per travel mode (vehicles sharing a mode share
 * the per-cell cache and one Route Matrix call).
 */
export async function etasByMode(
  items: readonly { at: { lat: number; lng: number }; vehicleKind: VehicleKind }[],
  many: (froms: { lat: number; lng: number }[], vehicleKind: VehicleKind) => Promise<number[]>,
): Promise<number[]> {
  const groups = new Map<string, number[]>();
  items.forEach((it, i) => {
    const mode = MapsService.travelMode(it.vehicleKind);
    groups.set(mode, [...(groups.get(mode) ?? []), i]);
  });
  const out: number[] = Array.from({ length: items.length }, () => 1);
  await Promise.all(
    [...groups.values()].map(async (idx) => {
      const mins = await many(idx.map((i) => items[i].at), items[idx[0]].vehicleKind);
      idx.forEach((i, j) => (out[i] = mins[j]));
    }),
  );
  return out;
}

const ETA_RES = 8;
const ETA_TTL_S = 600;

/**
 * ETA between two points: learned hex-pair speed (HexStatsService, from the exact points: in memory, free)
 * → Google road ETA → estimate. Road ETAs and estimates are cached per res-8 cell pair: every driver in the
 * same hexagon shares one lookup for 10 minutes, which keeps Routes API calls (and cost) low.
 */
@Injectable()
export class EtaService {
  constructor(
    private readonly maps: MapsService,
    private readonly redis: RedisService,
    private readonly hexStats: HexStatsService,
    private readonly settings: SettingsService,
  ) {}

  async minutes(params: { from: { lat: number; lng: number }; to: { lat: number; lng: number }; vehicleKind?: VehicleKind; useRoad: boolean }): Promise<number> {
    const a = cellAt(params.from.lat, params.from.lng, ETA_RES);
    const b = cellAt(params.to.lat, params.to.lng, ETA_RES);
    if (a === b) return 1;
    // 1. Learned speed for this hex pair and hour (finest resolution with enough completed trips).
    const minTrips = await this.settings.get('historicalEtaMinTrips');
    const learned = minTrips > 0 ? this.hexStats.speedKmh({ from: params.from, to: params.to, hour: istHour(new Date()), minTrips }) : null;
    if (learned) return etaMinutes(roadKm(params.from, params.to), learned.speed);
    // Per travel mode: a bike (two-wheeler) and a cab ETA for the same cells differ.
    const key = this.key(params.useRoad, MapsService.travelMode(params.vehicleKind), a, b);
    const hit = await this.redis.get(key);
    if (hit) return Number(hit);
    const eta = await this.compute(a, b, params);
    await this.redis.set(key, String(eta), 'EX', ETA_TTL_S);
    return eta;
  }

  /**
   * [minutes] for many drivers to one pickup, same order and same caches: learned speed first, then the per-cell-pair
   * cache (`eta:road|est:<mode>:<a>:<b>`), then ONE computeRouteMatrix call for every cell still missing (origins =
   * the missing cells' centres, destination = the pickup cell's centre; chunks of [MATRIX_MAX_ORIGINS]), then the
   * estimate for any element Google could not route. Every computed value is cached 10 min, as in [minutes].
   */
  async minutesMany(params: { froms: readonly Point[]; to: Point; vehicleKind?: VehicleKind; useRoad: boolean }): Promise<number[]> {
    const b = cellAt(params.to.lat, params.to.lng, ETA_RES);
    const minTrips = await this.settings.get('historicalEtaMinTrips');
    const hour = istHour(new Date());
    const mode = MapsService.travelMode(params.vehicleKind);
    const out: (number | null)[] = params.froms.map(() => null);
    /** Driver indexes waiting on each missing origin cell. */
    const missing = new Map<string, number[]>();
    await Promise.all(
      params.froms.map(async (from, i) => {
        const a = cellAt(from.lat, from.lng, ETA_RES);
        if (a === b) return void (out[i] = 1);
        const learned = minTrips > 0 ? this.hexStats.speedKmh({ from, to: params.to, hour, minTrips }) : null;
        if (learned) return void (out[i] = etaMinutes(roadKm(from, params.to), learned.speed));
        const hit = await this.redis.get(this.key(params.useRoad, mode, a, b));
        if (hit !== null) return void (out[i] = Number(hit));
        missing.set(a, [...(missing.get(a) ?? []), i]);
      }),
    );
    if (missing.size > 0) {
      const cells = [...missing.keys()];
      const [bLat, bLng] = cellToLatLng(b);
      const to = { lat: bLat, lng: bLng };
      const origins = cells.map((a) => {
        const [lat, lng] = cellToLatLng(a);
        return { lat, lng };
      });
      const legs: ({ durationMin: number } | null)[] = origins.map(() => null);
      if (params.useRoad && this.maps.isGoogleEnabled) {
        for (let start = 0; start < origins.length; start += MATRIX_MAX_ORIGINS) {
          const chunk = await this.maps.etaMatrix({ origins: origins.slice(start, start + MATRIX_MAX_ORIGINS), destination: to, vehicleKind: params.vehicleKind });
          chunk?.forEach((leg, j) => (legs[start + j] = leg));
        }
      }
      await Promise.all(
        cells.map(async (a, j) => {
          const eta = legs[j] ? Math.max(1, legs[j].durationMin) : etaMinutes(roadKm(origins[j], to), FALLBACK_KMH);
          await this.redis.set(this.key(params.useRoad, mode, a, b), String(eta), 'EX', ETA_TTL_S);
          for (const i of missing.get(a) ?? []) out[i] = eta;
        }),
      );
    }
    return out.map((m) => m ?? 1);
  }

  private key(useRoad: boolean, mode: string, a: string, b: string): string {
    return `eta:${useRoad ? 'road' : 'est'}:${mode}:${a}:${b}`;
  }

  private async compute(a: string, b: string, params: { vehicleKind?: VehicleKind; useRoad: boolean }): Promise<number> {
    const [aLat, aLng] = cellToLatLng(a);
    const [bLat, bLng] = cellToLatLng(b);
    const from = { lat: aLat, lng: aLng };
    const to = { lat: bLat, lng: bLng };
    // 2. Road ETA, 3. straight-line estimate.
    if (params.useRoad && this.maps.isGoogleEnabled) {
      const road = await this.maps.route({ from, to, vehicleKind: params.vehicleKind, stops: false });
      if (road) return Math.max(1, road.durationMin);
    }
    return etaMinutes(roadKm(from, to), FALLBACK_KMH);
  }
}
