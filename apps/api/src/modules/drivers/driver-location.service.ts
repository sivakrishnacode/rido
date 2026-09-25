import { Injectable } from '@nestjs/common';
import { gridDiskDistances } from 'h3-js';

import { RedisService } from '../../core/redis/redis.service.js';
import type { VehicleKind } from '../../generated/prisma/enums.js';
import { haversineMeters } from '../fares/fare-engine.js';
import { cellAt } from '../geo/h3.util.js';

/** Resolution used to index drivers (≈0.74 km² hexes, ~0.9 km between neighbouring centres). */
export const DRIVER_H3_RES = 8;
const RING_SPACING_KM = 0.92;
const ALIVE_TTL_S = 90;

/** A nearby available driver, found by hexagon rings. */
export interface NearbyDriver {
  readonly driverId: string;
  /** Straight-line distance (for display/tie-breaks; ranking uses road ETA). */
  readonly distanceKm: number;
  readonly lat: number;
  readonly lng: number;
  /** 0 = same hexagon as the pickup, 1 = the six touching it, … */
  readonly ring: number;
}

/**
 * Live driver positions indexed by H3 cell (Uber-style): each driver sits in one Redis set
 * `h3:drv:<kind>:<cell>`; search walks the pickup hexagon, then ring 1, ring 2… instead of
 * measuring distance to every driver. Heartbeat key drops stale drivers; busy flag while on a job.
 */
@Injectable()
export class DriverLocationService {
  constructor(private readonly redis: RedisService) {}

  private static cellKey(kind: VehicleKind, cell: string): string {
    return `h3:drv:${kind}:${cell}`;
  }

  async update(params: { driverId: string; kind: VehicleKind; lat: number; lng: number }): Promise<void> {
    const cell = cellAt(params.lat, params.lng, DRIVER_H3_RES);
    const prev = await this.redis.get(`driver:cell:${params.driverId}`);
    const next = `${params.kind}|${cell}`;
    const tx = this.redis.multi();
    if (prev && prev !== next) {
      const [pk, pc] = prev.split('|');
      tx.srem(DriverLocationService.cellKey(pk as VehicleKind, pc), params.driverId);
    }
    tx.sadd(DriverLocationService.cellKey(params.kind, cell), params.driverId)
      .set(`driver:cell:${params.driverId}`, next)
      .set(`driver:alive:${params.driverId}`, `${params.lat},${params.lng}`, 'EX', ALIVE_TTL_S);
    await tx.exec();
  }

  async remove(params: { driverId: string; kind: VehicleKind }): Promise<void> {
    const prev = await this.redis.get(`driver:cell:${params.driverId}`);
    const tx = this.redis.multi();
    if (prev) {
      const [pk, pc] = prev.split('|');
      tx.srem(DriverLocationService.cellKey(pk as VehicleKind, pc), params.driverId);
    }
    await tx.del(`driver:alive:${params.driverId}`, `driver:cell:${params.driverId}`).exec();
  }

  /** Last known position, if the driver is online. */
  async position(driverId: string): Promise<{ lat: number; lng: number } | null> {
    const raw = await this.redis.get(`driver:alive:${driverId}`);
    if (!raw) return null;
    const [lat, lng] = raw.split(',').map(Number);
    return { lat, lng };
  }

  async setBusy(driverId: string, tripId: string | null): Promise<void> {
    if (tripId) await this.redis.set(`driver:busy:${driverId}`, tripId);
    else await this.redis.del(`driver:busy:${driverId}`);
  }

  activeTrip(driverId: string): Promise<string | null> {
    return this.redis.get(`driver:busy:${driverId}`);
  }

  /**
   * Available drivers from the pickup hexagon outward, ring by ring, up to [radiusKm].
   * Stops after the ring where at least [limit] drivers were found.
   */
  async nearby(params: { kind: VehicleKind; lat: number; lng: number; radiusKm: number; limit: number }): Promise<NearbyDriver[]> {
    const origin = cellAt(params.lat, params.lng, DRIVER_H3_RES);
    const maxRing = Math.max(1, Math.ceil(params.radiusKm / RING_SPACING_KM));
    const rings = gridDiskDistances(origin, maxRing);
    const found: NearbyDriver[] = [];
    for (let ring = 0; ring < rings.length; ring++) {
      const keys = rings[ring].map((c) => DriverLocationService.cellKey(params.kind, c));
      const ids = keys.length ? await this.redis.sunion(...keys) : [];
      for (const driverId of ids) {
        const d = await this.available(driverId, params);
        if (d && d.distanceKm <= params.radiusKm) found.push({ ...d, ring });
      }
      if (found.length >= params.limit) break;
    }
    return found.sort((a, b) => a.ring - b.ring || a.distanceKm - b.distanceKm);
  }

  private async available(driverId: string, at: { lat: number; lng: number }): Promise<Omit<NearbyDriver, 'ring'> | null> {
    const [pos, isBusy] = await Promise.all([this.position(driverId), this.redis.exists(`driver:busy:${driverId}`)]);
    if (!pos || isBusy) return null;
    return { driverId, ...pos, distanceKm: haversineMeters(pos, at) / 1000 };
  }
}
