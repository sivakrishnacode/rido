import { Injectable } from '@nestjs/common';
import { cellsToMultiPolygon, cellToBoundary, cellToLatLng, cellToParent } from 'h3-js';

import { PrismaService } from '../../core/prisma/prisma.service.js';
import { RedisService } from '../../core/redis/redis.service.js';
import { DEMAND_RES, DemandService } from './demand.service.js';
import { GeoService } from './geo.service.js';

type LatLngPair = [number, number];

export type HotspotLevel = 'high' | 'busy' | 'some';

/** A res-8 hex (≈0.7 km²) inside a hotspot, shaded by its own pickups. */
export interface NestedHex {
  cell: string;
  /** 0–1, relative to the busiest nested hex in the same hotspot. */
  score: number;
  boundary: LatLngPair[];
}

export interface Hotspot {
  cell: string;
  level: HotspotLevel;
  /** 0–1, relative to the busiest hex shown. */
  score: number;
  /** Live surge on this hex (1 = none). */
  multiplier: number;
  centre: LatLngPair;
  boundary: LatLngPair[];
  /** Busy res-8 hexes inside (only those with pickups): where in the area the orders come from. */
  nested: NestedHex[];
}

export interface DriverMap {
  at: string;
  hotspots: Hotspot[];
  /** Outer rings of each city's service area (lat, lng), for the zoomed-out map. */
  serviceArea: LatLngPair[][];
}

const CACHE_KEY = 'drivermap:v2';
const CACHE_S = 60;
const MAX_HOTSPOTS = 30;
const RECENT_MIN = 60;
const HISTORY_DAYS = 28;

/**
 * The driver app's demand map: where orders come from, per res-7 hex (≈5 km²), and the service area outline.
 * Score = live demand (distinct riders in the demand window, ×3) + bookings in the last hour (×2) + the usual
 * pickups at this IST hour (±1) over the last 4 weeks (weekly average). Live surge cells are always "high". Each
 * hotspot also lists its busy res-8 children (recent + usual pickups), like H3's nested hex grid.
 * No rider counts are exposed; cached for a minute (one computation for all drivers).
 */
@Injectable()
export class DriverMapService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly redis: RedisService,
    private readonly demand: DemandService,
    private readonly geo: GeoService,
  ) {}

  async map(): Promise<DriverMap> {
    const cached = await this.redis.get(CACHE_KEY);
    if (cached) return JSON.parse(cached) as DriverMap;
    const map = await this.build(new Date());
    await this.redis.set(CACHE_KEY, JSON.stringify(map), 'EX', CACHE_S);
    return map;
  }

  async build(now: Date): Promise<DriverMap> {
    const [snapshot, recent, usual, serviceArea] = await Promise.all([
      this.demand.snapshot(),
      this.pickupsSince(new Date(now.getTime() - RECENT_MIN * 60_000)),
      this.usualPickups(now),
      this.serviceAreaOutline(),
    ]);
    const live = new Map(snapshot.cells.map((c) => [c.cell, c]));
    const scores = new Map<string, number>();
    const add = (cell: string, v: number): void => {
      scores.set(cell, (scores.get(cell) ?? 0) + v);
    };
    // Res-8 scores (pickup cells), rolled up to their res-7 parent for the hotspot score.
    const fine = new Map<string, number>();
    const addFine = (cell: string, v: number): void => {
      fine.set(cell, (fine.get(cell) ?? 0) + v);
      add(cellToParent(cell, DEMAND_RES), v);
    };
    for (const c of snapshot.cells) add(c.cell, c.requests * 3);
    for (const [cell, n] of recent) addFine(cell, n * 2);
    for (const [cell, n] of usual) addFine(cell, n);
    const nestedOf = new Map<string, [string, number][]>();
    for (const [cell, v] of fine) {
      const parent = cellToParent(cell, DEMAND_RES);
      nestedOf.set(parent, [...(nestedOf.get(parent) ?? []), [cell, v]]);
    }

    const ranked = [...scores].filter(([, s]) => s > 0).sort((a, b) => b[1] - a[1]).slice(0, MAX_HOTSPOTS);
    const top = ranked[0]?.[1] ?? 1;
    const hotspots = ranked.map(([cell, s]): Hotspot => {
      const score = Math.round((s / top) * 100) / 100;
      const l = live.get(cell);
      const surging = !!l && (l.level === 'high' || l.multiplier > 1);
      const level: HotspotLevel = surging || score >= 0.6 ? 'high' : score >= 0.3 || l?.level === 'busy' ? 'busy' : 'some';
      const [lat, lng] = cellToLatLng(cell);
      const kids = nestedOf.get(cell) ?? [];
      const busiest = Math.max(1e-9, ...kids.map(([, v]) => v));
      const nested = kids.map(([k, v]) => ({ cell: k, score: Math.round((v / busiest) * 100) / 100, boundary: cellToBoundary(k) as LatLngPair[] }));
      return { cell, level, score, multiplier: l?.multiplier ?? 1, centre: [lat, lng], boundary: cellToBoundary(cell) as LatLngPair[], nested };
    });
    return { at: now.toISOString(), hotspots, serviceArea };
  }

  /** Bookings (any outcome) per res-8 pickup hex since [since]. */
  private async pickupsSince(since: Date): Promise<Map<string, number>> {
    const rows = await this.prisma.trip.groupBy({ by: ['pickupCell'], where: { createdAt: { gte: since }, pickupCell: { not: null } }, _count: { _all: true } });
    return new Map(rows.map((r) => [r.pickupCell!, r._count._all]));
  }

  /** Weekly average of bookings per res-8 pickup hex at this IST hour ±1 over the last 4 weeks. */
  private async usualPickups(now: Date): Promise<Map<string, number>> {
    const hour = (now.getUTCHours() + 5 + (now.getUTCMinutes() >= 30 ? 1 : 0)) % 24;
    const hours = [(hour + 23) % 24, hour, (hour + 1) % 24];
    const rows = await this.prisma.$queryRaw<{ cell: string; n: bigint }[]>`
      SELECT "pickupCell" AS cell, count(*) AS n FROM "Trip"
      WHERE "createdAt" >= ${new Date(now.getTime() - HISTORY_DAYS * 86_400_000)} AND "pickupCell" IS NOT NULL
        AND extract(hour FROM ("createdAt" AT TIME ZONE 'UTC') AT TIME ZONE 'Asia/Kolkata')::int = ANY(${hours})
      GROUP BY 1`;
    const weeks = HISTORY_DAYS / 7;
    return new Map(rows.map((r) => [r.cell, Number(r.n) / weeks]));
  }

  /** Each active city's service cells merged into outer rings (holes dropped: the map only draws the edge). */
  private async serviceAreaOutline(): Promise<LatLngPair[][]> {
    const cities = await this.geo.activeCities();
    const rings: LatLngPair[][] = [];
    for (const c of cities) {
      const area = await this.geo.serviceArea(c.id);
      if (!area?.cells.length) continue;
      for (const polygon of cellsToMultiPolygon(area.cells, false)) rings.push(polygon[0] as LatLngPair[]);
    }
    return rings;
  }
}
