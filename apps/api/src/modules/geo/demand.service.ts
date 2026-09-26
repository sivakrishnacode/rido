import { Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { cellToChildren, cellToLatLng, gridDisk } from 'h3-js';

import { RedisService } from '../../core/redis/redis.service.js';
import { VehicleKind } from '../../generated/prisma/enums.js';
import { SettingsService } from '../settings/settings.service.js';
import { cellAt } from './h3.util.js';
import { DemandLevel, smoothSurge, surgeFor } from './surge.js';

/** Demand is measured on res-7 hexes (≈5 km²): big enough to have signal, small enough to be local. */
export const DEMAND_RES = 7;
const DRIVER_RES = 8;
const SNAPSHOT_KEY = 'h3:demand:snapshot';
const TICK_MS = 60_000;

/** One hexagon's live demand vs supply. */
export interface DemandCell {
  readonly cell: string;
  readonly lat: number;
  readonly lng: number;
  readonly requests: number;
  readonly freeDrivers: number;
  readonly ratio: number;
  readonly multiplier: number;
  readonly level: DemandLevel;
}

export interface DemandSnapshot {
  readonly at: string;
  readonly windowMin: number;
  readonly cells: DemandCell[];
}

/**
 * Live demand vs supply per H3 cell (owner H3 plan):
 * bookings increment a per-minute counter for their res-7 cell; once a minute the snapshot sums the
 * last `demandWindowMin` minutes, counts free drivers in the cell (from the res-8 driver index), and
 * writes a surge multiplier per cell (`h3:surge:<cell>`) that fares use, plus a snapshot for the
 * driver app's "High demand" areas and the admin panel. A Redis lock keeps it to one instance.
 */
@Injectable()
export class DemandService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(DemandService.name);
  private ticker: NodeJS.Timeout | null = null;

  constructor(
    private readonly redis: RedisService,
    private readonly settings: SettingsService,
  ) {}

  onModuleInit(): void {
    this.ticker = setInterval(() => void this.refresh().catch((e: Error) => this.logger.warn(e.message)), TICK_MS);
  }

  onModuleDestroy(): void {
    if (this.ticker) clearInterval(this.ticker);
  }

  private static bucket(ms: number): number {
    return Math.floor(ms / 60_000);
  }

  /**
   * Counts a booking at [point] in the current minute, **once per passenger**: someone re-booking or retrying
   * another vehicle is still one rider, so a single person can't create surge on their own.
   */
  async recordRequest(point: { lat: number; lng: number }, passengerId: string): Promise<void> {
    const cell = cellAt(point.lat, point.lng, DEMAND_RES);
    const b = DemandService.bucket(Date.now());
    const ttl = ((await this.settings.get('demandWindowMin')) + 5) * 60;
    const riders = `h3:riders:${b}:${cell}`;
    await this.redis.multi().sadd(riders, passengerId).expire(riders, ttl).sadd(`h3:req:${b}`, cell).expire(`h3:req:${b}`, ttl).exec();
  }

  /** Live surge multiplier at [point] (1 when none or disabled). */
  async surgeAt(point: { lat: number; lng: number }): Promise<number> {
    if (!(await this.settings.get('dynamicSurgeEnabled'))) return 1;
    const v = await this.redis.get(`h3:surge:${cellAt(point.lat, point.lng, DEMAND_RES)}`);
    return v ? Number(v) : 1;
  }

  async snapshot(): Promise<DemandSnapshot> {
    const raw = await this.redis.get(SNAPSHOT_KEY);
    return raw ? (JSON.parse(raw) as DemandSnapshot) : this.refresh(true);
  }

  /** Recomputes demand, supply and surge for every cell with recent bookings. */
  async refresh(force = false): Promise<DemandSnapshot> {
    const s = await this.settings.all();
    if (!force && !(await this.redis.set('h3:demand:lock', '1', 'PX', TICK_MS - 5_000, 'NX'))) return this.snapshot();
    const now = DemandService.bucket(Date.now());
    const buckets = Array.from({ length: s.demandWindowMin }, (_, i) => now - i);
    const cells = buckets.length ? await this.redis.sunion(...buckets.map((b) => `h3:req:${b}`)) : [];
    const result: DemandCell[] = [];
    for (const cell of cells) {
      // Distinct passengers who booked here in the window (sets of passenger ids per minute).
      const requests = (await this.redis.sunion(...buckets.map((b) => `h3:riders:${b}:${cell}`))).length;
      const freeDrivers = await this.freeDriversIn(cell);
      const { ratio, multiplier, level } = surgeFor({ requests, freeDrivers, sensitivity: s.surgeSensitivity, minRequests: s.surgeMinRequests, maxMultiplier: s.maxMultiplier });
      const [lat, lng] = cellToLatLng(cell);
      result.push({ cell, lat, lng, requests, freeDrivers, ratio: Math.round(ratio * 100) / 100, multiplier, level });
    }
    // Smooth across ring-1 neighbours so prices don't jump at hex edges, then publish per cell.
    const raw = new Map(result.map((c) => [c.cell, c.multiplier]));
    const smoothed = smoothSurge(raw, (c) => gridDisk(c, 1));
    const previous = await this.redis.keys('h3:surge:*');
    const tx = this.redis.multi();
    for (const k of previous) if (!smoothed.has(k.slice('h3:surge:'.length))) tx.del(k);
    for (const [cell, m] of smoothed) tx.set(`h3:surge:${cell}`, String(m), 'EX', 180);
    await tx.exec();
    for (const c of result) (c as { multiplier: number }).multiplier = smoothed.get(c.cell) ?? 1;
    const snap: DemandSnapshot = { at: new Date().toISOString(), windowMin: s.demandWindowMin, cells: result.sort((a, b) => b.ratio - a.ratio) };
    await this.redis.set(SNAPSHOT_KEY, JSON.stringify(snap), 'EX', 180);
    return snap;
  }

  /** Online, not-busy drivers of any vehicle kind inside a res-7 cell. */
  private async freeDriversIn(cell: string): Promise<number> {
    const children = cellToChildren(cell, DRIVER_RES);
    const keys = Object.values(VehicleKind).flatMap((k) => children.map((c) => `h3:drv:${k}:${c}`));
    const ids = await this.redis.sunion(...keys);
    let free = 0;
    for (const id of ids) {
      const [alive, busy] = await Promise.all([this.redis.exists(`driver:alive:${id}`), this.redis.exists(`driver:busy:${id}`)]);
      if (alive && !busy) free++;
    }
    return free;
  }
}
