import { ConflictException, Injectable, Logger, OnModuleInit } from '@nestjs/common';

import { DriverStateCache } from '../../core/driver-state/driver-state.cache.js';
import type { Job } from '../../core/jobs/job-runner.js';
import { JobsService } from '../../core/jobs/jobs.service.js';
import { PrismaService } from '../../core/prisma/prisma.service.js';
import { RedisService } from '../../core/redis/redis.service.js';
import type { DriverBlock, Prisma } from '../../generated/prisma/client.js';
import { CancelFault, DriverBlockReason } from '../../generated/prisma/enums.js';
import { DriverEarningsService } from '../drivers/driver-earnings.service.js';
import { DriverLocationService } from '../drivers/driver-location.service.js';
import { NotifierService } from '../notifications/notifier.service.js';
import { TripEventsService } from '../realtime/trip-events.service.js';
import { SettingsService } from '../settings/settings.service.js';
import { blockHours, CANCEL_RATE_WINDOW_MS, cancelRateLevel, type CancelRateLevel, cancelRateMessage, cancelRateSince } from './cancel-rate.js';

/** Durable job: the pause of a driver is over (id = driver id, payload = the block). */
export const UNBLOCK_JOB = 'driver.unblock';
/** Socket events to the driver's room. */
export const BLOCKED_EVENT = 'driver.blocked';
export const UNBLOCKED_EVENT = 'driver.unblocked';

/** Set while a driver is paused (PX until the end): dispatch skips them without a database read. */
export const blockedKey = (driverId: string): string => `driver:tblock:${driverId}`;
const statsKey = (driverId: string): string => `driver:cancel-rate:${driverId}`;
const nudgedKey = (driverId: string): string => `driver:cancel-nudged:${driverId}`;
const STATS_TTL_S = 300;
const NUDGE_EVERY_S = 86_400;

/** GET /drivers/me/cancel-rate: the driver's cancellation rate and what it means. */
export interface CancelRateStats {
  /** Window start (7 days back, or the end of the last pause). */
  readonly since: string;
  /** Driver-fault cancellations and assigned trips in the window. */
  readonly cancelled: number;
  readonly assigned: number;
  readonly rate: number;
  readonly level: CancelRateLevel;
  /** Paused until then (null = not paused). */
  readonly blockedUntil: string | null;
  readonly minTrips: number;
  readonly nudgeAt: number;
  readonly blockAt: number;
  readonly blockHours: number;
  /** The banner text when [level] is not OK. */
  readonly message: { title: string; body: string } | null;
}

/**
 * Driver cancellation rate, nudge and temporary pause (like Namma Yatri's `CancellationRate.nudgeOrBlockDriver` and
 * `UnblockDriver`). After every driver-fault cancellation ([afterCancel]): driver-fault cancellations ÷ assigned
 * trips over 7 days (`TripCancellation` + trips); from `cancelRateNudge` a push and an app banner, from
 * `cancelRateBlock` a [DriverBlock]: offline, can't go online (`DRIVER_TEMP_BLOCKED`), skipped by dispatch, and a
 * durable [UNBLOCK_JOB] at the end. Admins can lift it early ([lift]).
 */
@Injectable()
export class DriverBlocksService implements OnModuleInit {
  private readonly logger = new Logger(DriverBlocksService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly redis: RedisService,
    private readonly jobs: JobsService,
    private readonly state: DriverStateCache,
    private readonly location: DriverLocationService,
    private readonly earnings: DriverEarningsService,
    private readonly events: TripEventsService,
    private readonly notifier: NotifierService,
    private readonly settings: SettingsService,
  ) {}

  onModuleInit(): void {
    this.jobs.register(UNBLOCK_JOB, (j: Job<{ blockId: string }>) => this.expire(j.id, j.payload.blockId));
  }

  /** The driver's rate now (cached 5 min; dropped on each of their cancellations). */
  async stats(driverId: string, now = Date.now()): Promise<CancelRateStats> {
    const cached = await this.redis.get(statsKey(driverId));
    if (cached) return JSON.parse(cached) as CancelRateStats;
    const s = await this.settings.all();
    const [driver, lastBlock] = await Promise.all([
      this.prisma.driver.findUniqueOrThrow({ where: { id: driverId }, select: { blockedUntil: true } }),
      this.prisma.driverBlock.findFirst({ where: { driverId }, orderBy: { fromAt: 'desc' } }),
    ]);
    const since = cancelRateSince(now, lastBlock ? (lastBlock.liftedAt ?? lastBlock.untilAt) : null);
    const [cancelled, onTrips, reassigned] = await Promise.all([
      this.prisma.tripCancellation.count({ where: { driverId, fault: CancelFault.DRIVER, createdAt: { gte: since } } }),
      // Trips they still hold (done, cancelled or running) plus the ones taken off them (the trip row lost them).
      this.prisma.trip.count({ where: { driverId, assignedAt: { gte: since } } }),
      this.prisma.tripCancellation.count({ where: { driverId, reassigned: true, createdAt: { gte: since } } }),
    ]);
    const assigned = onTrips + reassigned;
    const { rate, level } = cancelRateLevel({ cancelled, assigned }, s);
    const blockedUntil = driver.blockedUntil && driver.blockedUntil.getTime() > now ? driver.blockedUntil.toISOString() : null;
    const stats: CancelRateStats = {
      since: since.toISOString(),
      cancelled,
      assigned: Math.max(assigned, cancelled),
      rate,
      level,
      blockedUntil,
      minTrips: s.cancelRateMinTrips,
      nudgeAt: s.cancelRateNudge,
      blockAt: s.cancelRateBlock,
      blockHours: s.cancelBlockHours,
      message: level === 'OK' ? null : cancelRateMessage({ cancelled, assigned: Math.max(assigned, cancelled), level }, s),
    };
    await this.redis.set(statsKey(driverId), JSON.stringify(stats), 'EX', STATS_TTL_S);
    return stats;
  }

  /** After a cancellation held against [driverId]: nudge or pause them when their rate crossed a threshold. */
  async afterCancel(driverId: string, now = Date.now()): Promise<CancelRateLevel> {
    await this.redis.del(statsKey(driverId));
    const stats = await this.stats(driverId, now);
    if (stats.level === 'BLOCK' && !stats.blockedUntil) {
      await this.block(driverId, stats, now);
    } else if (stats.level === 'NUDGE' && stats.message) {
      if ((await this.redis.set(nudgedKey(driverId), '1', 'EX', NUDGE_EVERY_S, 'NX')) === 'OK') {
        void this.notifier.driverAccount({ driverId, kind: 'CANCEL_RATE_NUDGE', ...stats.message });
      }
    }
    return stats.level;
  }

  /** Pauses the driver (offline, out of the index, can't go online) until `cancelBlockHours` from [now]. */
  private async block(driverId: string, stats: CancelRateStats, now: number): Promise<DriverBlock> {
    const s = await this.settings.all();
    const recent = await this.prisma.driverBlock.count({ where: { driverId, fromAt: { gte: new Date(now - CANCEL_RATE_WINDOW_MS) } } });
    const until = new Date(now + blockHours(recent > 0, s) * 3_600_000);
    const details = { cancelled: stats.cancelled, assigned: stats.assigned, rate: stats.rate, since: stats.since } as Prisma.InputJsonValue;
    const [block, driver] = await this.prisma.$transaction([
      this.prisma.driverBlock.create({ data: { driverId, reason: DriverBlockReason.CANCELLATION_RATE, fromAt: new Date(now), untilAt: until, details } }),
      this.prisma.driver.update({ where: { id: driverId }, data: { blockedUntil: until, isOnline: false }, select: { vehicleKind: true } }),
    ]);
    await this.redis.set(blockedKey(driverId), String(until.getTime()), 'PX', Math.max(1, until.getTime() - now));
    await this.location.remove({ driverId, kind: driver.vehicleKind });
    await this.earnings.sessionEnded(driverId);
    await this.state.invalidate(driverId);
    await this.redis.del(statsKey(driverId));
    await this.jobs.schedule(UNBLOCK_JOB, driverId, until.getTime(), { blockId: block.id });
    const message = cancelRateMessage({ ...stats, level: 'BLOCK' }, s);
    this.events.toDriver(driverId, BLOCKED_EVENT, { until: until.toISOString(), ...message });
    void this.notifier.driverAccount({ driverId, kind: 'TEMP_BLOCKED', title: message.title, body: `${message.body}. You can go online again at ${istTime(until)}` });
    this.logger.log(`Driver ${driverId} paused until ${until.toISOString()} (${stats.cancelled}/${stats.assigned} cancelled)`);
    return block;
  }

  /** [UNBLOCK_JOB]: the pause ran its course. A stale job (lifted, or a newer pause) does nothing. */
  async expire(driverId: string, blockId: string): Promise<void> {
    const block = await this.prisma.driverBlock.findUnique({ where: { id: blockId } });
    if (!block || block.liftedAt) return;
    const { count } = await this.prisma.driver.updateMany({ where: { id: driverId, blockedUntil: block.untilAt }, data: { blockedUntil: null } });
    if (count === 0) return;
    await this.cleared(driverId);
    void this.notifier.driverAccount({ driverId, kind: 'UNBLOCKED', title: 'You can go online again', body: 'Your pause is over. Please only accept rides you can reach' });
  }

  /** Admin: ends the driver's current pause now (audit logged by the admin controller). */
  async lift(driverId: string, adminUserId: string): Promise<DriverBlock> {
    const now = new Date();
    const block = await this.prisma.driverBlock.findFirst({ where: { driverId, liftedAt: null, untilAt: { gt: now } }, orderBy: { fromAt: 'desc' } });
    if (!block) throw new ConflictException('This driver is not paused');
    const [lifted] = await this.prisma.$transaction([
      this.prisma.driverBlock.update({ where: { id: block.id }, data: { liftedBy: adminUserId, liftedAt: now } }),
      this.prisma.driver.update({ where: { id: driverId }, data: { blockedUntil: null } }),
    ]);
    await this.jobs.cancel(UNBLOCK_JOB, driverId);
    await this.cleared(driverId);
    void this.notifier.driverAccount({ driverId, kind: 'UNBLOCKED', title: 'You can go online again', body: 'Tamil Taxi support lifted your pause' });
    return lifted;
  }

  /** Newest first (admin driver page). */
  history(driverId: string): Promise<DriverBlock[]> {
    return this.prisma.driverBlock.findMany({ where: { driverId }, orderBy: { fromAt: 'desc' }, take: 20 });
  }

  /** Of [driverIds], those paused right now (dispatch skips them). */
  async pausedAmong(driverIds: readonly string[]): Promise<Set<string>> {
    if (driverIds.length === 0) return new Set();
    const flags = await this.redis.mget(...driverIds.map(blockedKey));
    return new Set(driverIds.filter((_, i) => flags[i] !== null));
  }

  private async cleared(driverId: string): Promise<void> {
    await this.redis.del(blockedKey(driverId), statsKey(driverId));
    await this.state.invalidate(driverId);
    this.events.toDriver(driverId, UNBLOCKED_EVENT, {});
  }
}

/** "3:40 PM, 29 Sep" in IST. */
export function istTime(d: Date): string {
  return d.toLocaleString('en-IN', { timeZone: 'Asia/Kolkata', hour: 'numeric', minute: '2-digit', hour12: true, day: 'numeric', month: 'short' });
}
