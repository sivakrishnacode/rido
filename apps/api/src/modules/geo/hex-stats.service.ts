import { Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { cellToParent } from 'h3-js';

import { PrismaService } from '../../core/prisma/prisma.service.js';
import { RedisService } from '../../core/redis/redis.service.js';
import type { HexStat } from '../../generated/prisma/client.js';
import { TripStatus } from '../../generated/prisma/enums.js';
import { etaMinutes, FALLBACK_KMH, roadKm } from './eta-model.js';
import { cellAt } from './h3.util.js';

const LOOKBACK_DAYS = 60;
const MIN_KMH = 3;
const MAX_KMH = 80;
const REBUILD_EVERY_MS = 24 * 3600_000;
const CHECK_EVERY_MS = 30 * 60_000;
/** Learned at street (≈0.1 km²), neighbourhood (≈0.7 km²) and district (≈5 km²) level; finest first. */
export const HEX_STAT_RES = [9, 8, 7] as const;
export type HexStatRes = (typeof HEX_STAT_RES)[number];
const INSERT_CHUNK = 5000;

/** IST hour (0–23) of a date. */
export function istHour(d: Date): number {
  return (d.getUTCHours() + 5 + (d.getUTCMinutes() + 30 >= 60 ? 1 : 0)) % 24;
}

/** Key for the in-memory speed table. */
function key(from: string, to: string, hour: number | '*'): string {
  return `${from}|${to}|${hour}`;
}

/** A learned speed and where it came from. */
export interface LearnedSpeed {
  speed: number;
  trips: number;
  res: HexStatRes;
  hour: number | '*';
}

/**
 * Learned travel speeds between hexes by IST hour, from completed trips of the last 60 days
 * (owner H3 plan: "ETA from historical speed per hex pair and hour"). Every trip counts at res 9, 8 and 7;
 * lookups back off from the finest pair with enough trips to coarser ones, so busy streets get
 * street-level speeds while quiet areas still get a stable district average. Rebuilt daily (Redis lock,
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

  /**
   * Learned speed from [from] to [to] at [hour]. Traffic depends on the hour more than on the exact street, so the
   * exact hour is tried at res 9 → 8 → 7 before the all-hours average at res 9 → 8 → 7.
   */
  speedKmh(p: { from: { lat: number; lng: number }; to: { lat: number; lng: number }; hour: number; minTrips: number }): LearnedSpeed | null {
    const pairs = HEX_STAT_RES.map((res) => ({ res, from: cellAt(p.from.lat, p.from.lng, res), to: cellAt(p.to.lat, p.to.lng, res) }));
    for (const hour of [p.hour, '*'] as const) {
      for (const { res, from, to } of pairs) {
        const hit = this.table.get(key(from, to, hour));
        if (hit && hit.trips >= p.minTrips) return { ...hit, res, hour };
      }
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
      select: { pickupLat: true, pickupLng: true, dropLat: true, dropLng: true, distanceKm: true, startedAt: true, endedAt: true },
      take: 200_000,
    });
    const agg = new Map<string, { from: string; to: string; res: HexStatRes; hour: number; n: number; km: number; minutes: number }>();
    let used = 0;
    for (const t of trips) {
      const minutes = (t.endedAt!.getTime() - t.startedAt!.getTime()) / 60_000;
      const speed = t.distanceKm / (minutes / 60);
      if (!(minutes > 0) || speed < MIN_KMH || speed > MAX_KMH) continue;
      used++;
      const hour = istHour(t.startedAt!);
      // Exact pickup / drop points at the finest resolution; coarser cells are their parents.
      const from9 = cellAt(t.pickupLat, t.pickupLng, HEX_STAT_RES[0]);
      const to9 = cellAt(t.dropLat, t.dropLng, HEX_STAT_RES[0]);
      for (const res of HEX_STAT_RES) {
        const from = res === HEX_STAT_RES[0] ? from9 : cellToParent(from9, res);
        const to = res === HEX_STAT_RES[0] ? to9 : cellToParent(to9, res);
        const k = key(from, to, hour);
        const a = agg.get(k) ?? { from, to, res, hour, n: 0, km: 0, minutes: 0 };
        a.n++;
        a.km += t.distanceKm;
        a.minutes += minutes;
        agg.set(k, a);
      }
    }
    // Speed = total km / total time: a mean of per-trip speeds over-weights short, noisy trips.
    const rows = [...agg.values()].map((a) => ({
      fromCell: a.from, toCell: a.to, res: a.res, hour: a.hour, trips: a.n,
      avgSpeedKmh: a.km / (a.minutes / 60), avgDurationMin: a.minutes / a.n,
    }));
    const inserts = [];
    for (let i = 0; i < rows.length; i += INSERT_CHUNK) inserts.push(this.prisma.hexStat.createMany({ data: rows.slice(i, i + INSERT_CHUNK) }));
    await this.prisma.$transaction([this.prisma.hexStat.deleteMany({}), ...inserts]);
    await this.redis.set('hexstats:lastRun', String(Date.now()));
    await this.load();
    this.logger.log(`Hex stats rebuilt: ${rows.length} hex-pair/hour rows from ${used} trips`);
    return { pairs: rows.length, trips: used };
  }

  /** Loads HexStat rows into memory, plus an all-hours average per pair. */
  async load(): Promise<void> {
    const rows = await this.prisma.hexStat.findMany();
    const table = new Map<string, { trips: number; speed: number }>();
    const all = new Map<string, { trips: number; km: number; minutes: number }>();
    for (const r of rows) {
      table.set(key(r.fromCell, r.toCell, r.hour), { trips: r.trips, speed: r.avgSpeedKmh });
      const k = key(r.fromCell, r.toCell, '*');
      const a = all.get(k) ?? { trips: 0, km: 0, minutes: 0 };
      const minutes = r.avgDurationMin * r.trips;
      a.trips += r.trips;
      a.km += (r.avgSpeedKmh * minutes) / 60;
      a.minutes += minutes;
      all.set(k, a);
    }
    for (const [k, a] of all) table.set(k, { trips: a.trips, speed: a.km / (a.minutes / 60) });
    this.table = table;
  }

  /**
   * For the admin panel: learned rows at [res] (filtered by hour / min trips, sorted), speed by hour and per
   * pickup hex (slow areas), and an ETA check that replays recent trips through [speedKmh].
   */
  async summary(q: HexStatsQuery): Promise<HexStatsSummary> {
    const where = { res: q.res, trips: { gte: q.usedOnly ? Math.max(1, q.minTrips) : 1 }, ...(q.hour === undefined ? {} : { hour: q.hour }) };
    const orderBy =
      q.sort === 'slowest' ? [{ avgSpeedKmh: 'asc' as const }, { trips: 'desc' as const }]
      : q.sort === 'fastest' ? [{ avgSpeedKmh: 'desc' as const }, { trips: 'desc' as const }]
      : [{ trips: 'desc' as const }, { avgSpeedKmh: 'asc' as const }];
    const [counts, lastRun, top, all] = await Promise.all([
      this.prisma.hexStat.groupBy({ by: ['res'], _count: { _all: true } }),
      this.redis.get('hexstats:lastRun'),
      this.prisma.hexStat.findMany({ where, orderBy, take: q.limit }),
      this.prisma.hexStat.findMany({ where: { res: q.res }, select: { fromCell: true, hour: true, trips: true, avgSpeedKmh: true, avgDurationMin: true } }),
    ]);
    const byRes = Object.fromEntries(HEX_STAT_RES.map((r) => [r, counts.find((c) => c.res === r)?._count._all ?? 0])) as Record<HexStatRes, number>;

    // Speed = total km / total time, per hour (all rows) and per pickup hex (hour filter applies).
    const hours = new Map<number, Acc>();
    const areas = new Map<string, Acc>();
    for (const r of all) {
      add(hours, r.hour, r);
      if (q.hour === undefined || r.hour === q.hour) add(areas, r.fromCell, r);
    }
    return {
      res: q.res,
      rows: byRes[q.res],
      byRes,
      lastRun: lastRun ? new Date(Number(lastRun)).toISOString() : null,
      top,
      byHour: [...hours].sort(([a], [b]) => a - b).map(([hour, a]) => ({ hour, ...speedOf(a) })),
      areas: [...areas].map(([cell, a]) => ({ cell, ...speedOf(a) })).filter((a) => a.trips >= 2),
      accuracy: await this.accuracy(q.minTrips),
    };
  }

  /**
   * Replays finished trips of the last [ACCURACY_DAYS] through the learned speeds (as EtaService would at their start
   * hour) and compares with the real trip time. In-sample: these trips are part of the learned data, so it is an upper
   * bound on accuracy; the "fallback" row (no learned pair) uses the 20 km/h estimate, not Google.
   */
  private async accuracy(minTrips: number): Promise<EtaAccuracy> {
    const trips = await this.prisma.trip.findMany({
      where: { status: { in: [TripStatus.COMPLETED, TripStatus.DELIVERED] }, startedAt: { gte: new Date(Date.now() - ACCURACY_DAYS * 86_400_000) }, endedAt: { not: null } },
      select: { pickupLat: true, pickupLng: true, dropLat: true, dropLng: true, distanceKm: true, startedAt: true, endedAt: true },
      orderBy: { startedAt: 'desc' },
      take: 20_000,
    });
    const bySource = new Map<EtaSource, { n: number; abs: number; pct: number; bias: number }>();
    const total = { n: 0, abs: 0, pct: 0, bias: 0 };
    for (const t of trips) {
      const actual = (t.endedAt!.getTime() - t.startedAt!.getTime()) / 60_000;
      // Same trips the speeds are learned from (plausible speed), and ≥ 1 min so % errors stay meaningful.
      const speed = t.distanceKm / (actual / 60);
      if (!(actual >= 1) || speed < MIN_KMH || speed > MAX_KMH) continue;
      const from = { lat: t.pickupLat, lng: t.pickupLng };
      const to = { lat: t.dropLat, lng: t.dropLng };
      const hit = minTrips > 0 ? this.speedKmh({ from, to, hour: istHour(t.startedAt!), minTrips }) : null;
      const source: EtaSource = !hit ? 'fallback' : hit.hour === '*' ? 'all-day' : `res${hit.res}`;
      const err = etaMinutes(roadKm(from, to), hit?.speed ?? FALLBACK_KMH) - actual;
      for (const a of [total, bySource.get(source) ?? bySource.set(source, { n: 0, abs: 0, pct: 0, bias: 0 }).get(source)!]) {
        a.n++;
        a.abs += Math.abs(err);
        a.pct += Math.abs(err) / actual;
        a.bias += err;
      }
    }
    const stats = (a: { n: number; abs: number; pct: number; bias: number }) => ({
      trips: a.n,
      maeMin: a.n ? a.abs / a.n : 0,
      mapePct: a.n ? (a.pct / a.n) * 100 : 0,
      biasMin: a.n ? a.bias / a.n : 0,
    });
    const order: EtaSource[] = ['res9', 'res8', 'res7', 'all-day', 'fallback'];
    return {
      days: ACCURACY_DAYS,
      ...stats(total),
      sources: order.filter((s) => bySource.has(s)).map((source) => ({ source, ...stats(bySource.get(source)!) })),
    };
  }
}

const ACCURACY_DAYS = 14;

interface Acc {
  trips: number;
  km: number;
  minutes: number;
}

function add(map: Map<string | number, Acc>, k: string | number, r: { trips: number; avgSpeedKmh: number; avgDurationMin: number }): void {
  const a = map.get(k) ?? { trips: 0, km: 0, minutes: 0 };
  const minutes = r.avgDurationMin * r.trips;
  a.trips += r.trips;
  a.km += (r.avgSpeedKmh * minutes) / 60;
  a.minutes += minutes;
  map.set(k, a);
}

function speedOf(a: Acc): { speed: number; trips: number } {
  return { speed: a.minutes ? a.km / (a.minutes / 60) : 0, trips: a.trips };
}

export interface HexStatsQuery {
  res: HexStatRes;
  /** IST hour 0–23; all hours when undefined. */
  hour?: number;
  sort: 'busiest' | 'slowest' | 'fastest';
  /** Only pairs with ≥ minTrips (the ones ETAs actually use). */
  usedOnly: boolean;
  minTrips: number;
  limit: number;
}

export type EtaSource = 'res9' | 'res8' | 'res7' | 'all-day' | 'fallback';

export interface EtaAccuracy {
  days: number;
  trips: number;
  /** Mean absolute error, minutes. */
  maeMin: number;
  /** Mean absolute percentage error. */
  mapePct: number;
  /** Mean (predicted − actual): positive = ETAs too long. */
  biasMin: number;
  sources: { source: EtaSource; trips: number; maeMin: number; mapePct: number; biasMin: number }[];
}

export interface HexStatsSummary {
  res: HexStatRes;
  /** Rows at [res]. */
  rows: number;
  byRes: Record<HexStatRes, number>;
  lastRun: string | null;
  top: HexStat[];
  /** All rows at [res]: speed per IST hour. */
  byHour: { hour: number; speed: number; trips: number }[];
  /** Speed of trips leaving each hex at [res] (hour filter applies); hexes with ≥ 2 trips. */
  areas: { cell: string; speed: number; trips: number }[];
  accuracy: EtaAccuracy;
}
