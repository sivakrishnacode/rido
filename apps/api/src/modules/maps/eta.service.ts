import { Injectable } from '@nestjs/common';
import { cellToLatLng } from 'h3-js';

import { RedisService } from '../../core/redis/redis.service.js';
import type { VehicleKind } from '../../generated/prisma/enums.js';
import { etaMinutes, FALLBACK_KMH, roadKm } from '../geo/eta-model.js';
import { cellAt } from '../geo/h3.util.js';
import { HexStatsService, istHour } from '../geo/hex-stats.service.js';
import { SettingsService } from '../settings/settings.service.js';
import { MapsService } from './maps.service.js';

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
    const key = `eta:${params.useRoad ? 'road' : 'est'}:${a}:${b}`;
    const hit = await this.redis.get(key);
    if (hit) return Number(hit);
    const eta = await this.compute(a, b, params);
    await this.redis.set(key, String(eta), 'EX', ETA_TTL_S);
    return eta;
  }

  private async compute(a: string, b: string, params: { vehicleKind?: VehicleKind; useRoad: boolean }): Promise<number> {
    const [aLat, aLng] = cellToLatLng(a);
    const [bLat, bLng] = cellToLatLng(b);
    const from = { lat: aLat, lng: aLng };
    const to = { lat: bLat, lng: bLng };
    // 2. Road ETA, 3. straight-line estimate.
    if (params.useRoad && this.maps.isGoogleEnabled) {
      const road = await this.maps.route({ from, to, vehicleKind: params.vehicleKind });
      if (road) return Math.max(1, road.durationMin);
    }
    return etaMinutes(roadKm(from, to), FALLBACK_KMH);
  }
}
