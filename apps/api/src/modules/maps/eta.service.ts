import { Injectable } from '@nestjs/common';
import { cellToLatLng } from 'h3-js';

import { RedisService } from '../../core/redis/redis.service.js';
import type { VehicleKind } from '../../generated/prisma/enums.js';
import { haversineMeters } from '../fares/fare-engine.js';
import { cellAt } from '../geo/h3.util.js';
import { MapsService } from './maps.service.js';

const ETA_RES = 8;
const ETA_TTL_S = 600;
/** City approach speed when no road ETA is available. */
const FALLBACK_KMH = 20;
const ROAD_FACTOR = 1.3;

/**
 * Road ETA between two points, cached per H3 cell pair: every driver in the same hexagon
 * shares one lookup for 10 minutes, which keeps Routes API calls (and cost) low.
 */
@Injectable()
export class EtaService {
  constructor(
    private readonly maps: MapsService,
    private readonly redis: RedisService,
  ) {}

  async minutes(params: { from: { lat: number; lng: number }; to: { lat: number; lng: number }; vehicleKind?: VehicleKind; useRoad: boolean }): Promise<number> {
    const a = cellAt(params.from.lat, params.from.lng, ETA_RES);
    const b = cellAt(params.to.lat, params.to.lng, ETA_RES);
    if (a === b) return 1;
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
    if (params.useRoad && this.maps.isGoogleEnabled) {
      const road = await this.maps.route({ from, to, vehicleKind: params.vehicleKind });
      if (road) return Math.max(1, road.durationMin);
    }
    const km = (haversineMeters(from, to) / 1000) * ROAD_FACTOR;
    return Math.max(1, Math.round((km / FALLBACK_KMH) * 60));
  }
}
