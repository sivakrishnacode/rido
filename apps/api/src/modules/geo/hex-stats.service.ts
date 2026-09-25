import { Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { cellToParent } from 'h3-js';

import { PrismaService } from '../../core/prisma/prisma.service.js';
import { RedisService } from '../../core/redis/redis.service.js';
import type { HexStat } from '../../generated/prisma/client.js';
import { TripStatus } from '../../generated/prisma/enums.js';
import { DEMAND_RES } from './demand.service.js';

const LOOKBACK_DAYS = 60;
const MIN_KMH = 3;
const MAX_KMH = 80;
const REBUILD_EVERY_MS = 24 * 3600_000;
const CHECK_EVERY_MS = 30 * 60_000;

/** IST hour (0–23) of a date. */
export function istHour(d: Date): number {
  return (d.getUTCHours() + 5 + (d.getUTCMinutes() + 30 >= 60 ? 1 : 0)) % 24;
}

/** Key for the in-memory speed table. */
function key(from: string, to: string, hour: number | '*'): string {
  return `${from}|${to}|${hour}`;
}

/**
 * Learned travel speeds between res-7 hexes by IST hour, from completed trips of the last 60 days
 * (owner H3 plan: "ETA from historical speed per hex pair and hour"). Rebuilt daily (Redis lock,
 * one instance) or on demand from the admin panel; kept in memory for fast ETA lookups.
 */
@Injectable()
export class HexStatsService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(HexStatsService.name);
  private table = new Map<string, { trips: number; speed: number }>();
  private timer: NodeJS.Timeout | null = null;

  constructor(
    private readonly prisma: PrismaService,
    private readonly redis: RedisService,
  ) {}

  async onModuleInit(): Promise<void> {
    await this.load().catch((e: Error) => this.logger.warn(`Hex stats load failed: ${e.message}`));
    this.timer = setInterval(() => void this.maybeRebuild(), CHECK_EVERY_MS);
  }

  onModuleDestroy(): void {
    if (this.timer) clearInterval(this.timer);
  }

  /** Learned speed for a trip starting in [from] to [to] at [hour]; exact hour first, then all hours. */
  speedKmh(p: { from: string; to: string; hour: number; minTrips: number }): { speed: number; trips: number } | null {
    const from = cellToParent(p.from, DEMAND_RES);
    const to = cellToParent(p.to, DEMAND_RES);
    for (const k of [key(from, to, p.hour), key(from, to, '*')]) {
      const hit = this.table.get(k);
      if (hit && hit.trips >= p.minTrips) return hit;
    }
    return null;
  }

  private async maybeRebuild(): Promise<void> {
    const last = Number((await this.redis.get('hexstats:lastRun')) ?? 0);
    if (Date.now() - last < REBUILD_EVERY_MS) return this.load();
    if (!(await this.redis.set('hexstats:lock', '1', 'PX', 10 * 60_000, 'NX'))) return;
    await this.rebuild().catch((e: Error) => this.logger.warn(`Hex stats rebuild failed: ${e.message}`));
  }

  /** Aggregates completed trips into HexStat rows (replaces the table). */
  async rebuild(): Promise<{ pairs: number; trips: number }> {
    const since = new Date(Date.now() - LOOKBACK_DAYS * 86_400_000);
    const trips = await this.prisma.trip.findMany({
      where: { status: { in: [TripStatus.COMPLETED, TripStatus.DELIVERED] }, startedAt: { gte: since }, endedAt: { not: null }, pickupCell: { not: null }, dropCell: { not: null } },
      select: { pickupCell: true, dropCell: true, distanceKm: true, startedAt: true, endedAt: true },
      take: 200_000,
    });
    const agg = new Map<string, { from: string; to: string; hour: number; n: number; speed: number; minutes: number }>();
    let used = 0;
    for (const t of trips) {
      const minutes = (t.endedAt!.getTime() - t.startedAt!.getTime()) / 60_000;
      const speed = t.distanceKm / (minutes / 60);
      if (!(minutes > 0) || speed < MIN_KMH || speed > MAX_KMH) continue;
      used++;
      const from = cellToParent(t.pickupCell!, DEMAND_RES);
      const to = cellToParent(t.dropCell!, DEMAND_RES);
      const hour = istHour(t.startedAt!);
      const k = key(from, to, hour);
      const a = agg.get(k) ?? { from, to, hour, n: 0, speed: 0, minutes: 0 };
      a.n++;
      a.speed += speed;
      a.minutes += minutes;
      agg.set(k, a);
    }
    const rows = [...agg.values()].map((a) => ({ fromCell: a.from, toCell: a.to, hour: a.hour, trips: a.n, avgSpeedKmh: a.speed / a.n, avgDurationMin: a.minutes / a.n }));
    await this.prisma.$transaction([this.prisma.hexStat.deleteMany({}), this.prisma.hexStat.createMany({ data: rows })]);
    await this.redis.set('hexstats:lastRun', String(Date.now()));
    await this.load();
    this.logger.log(`Hex stats rebuilt: ${rows.length} hex-pair/hour rows from ${used} trips`);
    return { pairs: rows.length, trips: used };
  }

  /** Loads HexStat rows into memory, plus an all-hours average per pair. */
  async load(): Promise<void> {
    const rows = await this.prisma.hexStat.findMany();
    const table = new Map<string, { trips: number; speed: number }>();
    const all = new Map<string, { trips: number; weighted: number }>();
    for (const r of rows) {
      table.set(key(r.fromCell, r.toCell, r.hour), { trips: r.trips, speed: r.avgSpeedKmh });
      const k = key(r.fromCell, r.toCell, '*');
      const a = all.get(k) ?? { trips: 0, weighted: 0 };
      a.trips += r.trips;
      a.weighted += r.avgSpeedKmh * r.trips;
      all.set(k, a);
    }
    for (const [k, a] of all) table.set(k, { trips: a.trips, speed: a.weighted / a.trips });
    this.table = table;
  }

  /** For the admin panel: summary and busiest pairs. */
  async summary(limit = 50): Promise<{ rows: number; lastRun: string | null; top: HexStat[] }> {
    const [rows, lastRun, top] = await Promise.all([
      this.prisma.hexStat.count(),
      this.redis.get('hexstats:lastRun'),
      this.prisma.hexStat.findMany({ orderBy: { trips: 'desc' }, take: limit }),
    ]);
    return { rows, lastRun: lastRun ? new Date(Number(lastRun)).toISOString() : null, top };
  }
}
