import { Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';

import { PrismaService } from '../../core/prisma/prisma.service.js';
import { RedisService } from '../../core/redis/redis.service.js';
import type { Trip } from '../../generated/prisma/client.js';
import { TripStatus } from '../../generated/prisma/enums.js';
import { DriverLocationService } from '../drivers/driver-location.service.js';
import { EtaService } from '../maps/eta.service.js';
import { TripEventsService } from '../realtime/trip-events.service.js';
import { SettingsService } from '../settings/settings.service.js';
import { assignBatch, BatchRequest } from './batch-assign.js';

const PENDING_KEY = 'dispatch:pending';
const LOCK_KEY = 'dispatch:lock';

/**
 * Uber-style dispatch:
 * 1. Bookings wait in a short batch window (`batchWindowMs`, default 2 s).
 * 2. For each booking, drivers are found by H3 rings around the pickup (pickup hexagon, then neighbours…).
 * 3. Candidates are ranked by road ETA (cached per hex pair), not straight-line distance.
 * 4. The whole batch is assigned together so two riders never get the same driver.
 * 5. Each driver gets `offerSeconds` to accept; decline/timeout moves to the next in that trip's queue.
 * A Redis lock makes only one API instance run a batch at a time.
 */
@Injectable()
export class DispatchService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(DispatchService.name);
  private readonly timers = new Map<string, NodeJS.Timeout>();
  private ticker: NodeJS.Timeout | null = null;
  private isTicking = false;

  constructor(
    private readonly redis: RedisService,
    private readonly prisma: PrismaService,
    private readonly location: DriverLocationService,
    private readonly events: TripEventsService,
    private readonly settings: SettingsService,
    private readonly eta: EtaService,
  ) {}

  async onModuleInit(): Promise<void> {
    const windowMs = await this.settings.get('batchWindowMs');
    this.ticker = setInterval(() => void this.tick(), Math.max(250, windowMs));
  }

  onModuleDestroy(): void {
    if (this.ticker) clearInterval(this.ticker);
    for (const t of this.timers.values()) clearTimeout(t);
  }

  /** Queues a booking for the next batch. */
  async start(trip: Trip): Promise<void> {
    await this.redis.sadd(PENDING_KEY, trip.id);
  }

  /** Current offered driver for a trip, if any. */
  offeredTo(tripId: string): Promise<string | null> {
    return this.redis.get(`dispatch:${tripId}:offer`);
  }

  /** Driver declined or the offer timed out: try the next candidate. */
  async next(tripId: string): Promise<void> {
    await this.redis.del(`dispatch:${tripId}:offer`);
    await this.offerNext(tripId);
  }

  /** Stops dispatching (trip accepted or cancelled). */
  async stop(tripId: string): Promise<void> {
    clearTimeout(this.timers.get(tripId));
    this.timers.delete(tripId);
    await this.redis.srem(PENDING_KEY, tripId);
    await this.redis.del(`dispatch:${tripId}:offer`, `dispatch:${tripId}:queue`);
  }

  /** Runs one batch: takes all pending bookings, ranks candidates by ETA, assigns across the batch. */
  async tick(): Promise<number> {
    if (this.isTicking) return 0;
    this.isTicking = true;
    try {
      const windowMs = await this.settings.get('batchWindowMs');
      const gotLock = await this.redis.set(LOCK_KEY, '1', 'PX', Math.max(500, windowMs - 100), 'NX');
      if (!gotLock) return 0;
      const ids = await this.redis.spop(PENDING_KEY, 500);
      if (ids.length === 0) return 0;
      const trips = await this.prisma.trip.findMany({ where: { id: { in: ids }, status: TripStatus.SEARCHING } });
      const requests = await Promise.all(trips.map((t) => this.request(t)));
      const queues = assignBatch(requests);
      for (const trip of trips) {
        const queue = queues.get(trip.id) ?? [];
        const key = `dispatch:${trip.id}:queue`;
        await this.redis.del(key);
        if (queue.length > 0) await this.redis.rpush(key, ...queue);
        await this.redis.expire(key, 600);
        await this.offerNext(trip.id);
      }
      return trips.length;
    } catch (e) {
      this.logger.error(`Batch failed: ${(e as Error).message}`);
      return 0;
    } finally {
      this.isTicking = false;
    }
  }

  private async request(trip: Trip): Promise<BatchRequest> {
    const s = await this.settings.all();
    const pickup = { lat: trip.pickupLat, lng: trip.pickupLng };
    const nearby = await this.location.nearby({ kind: trip.vehicleKind, ...pickup, radiusKm: s.searchRadiusKm, limit: s.maxCandidates * 2 });
    const withEta = await Promise.all(
      nearby.map(async (d) => ({
        driverId: d.driverId,
        etaMin: await this.eta.minutes({ from: d, to: pickup, vehicleKind: trip.vehicleKind, useRoad: s.useRoadEta }),
      })),
    );
    const candidates = withEta.sort((a, b) => a.etaMin - b.etaMin).slice(0, s.maxCandidates);
    return { tripId: trip.id, createdAt: trip.createdAt, candidates };
  }

  private async offerNext(tripId: string): Promise<void> {
    const trip = await this.prisma.trip.findUnique({ where: { id: tripId } });
    if (!trip || trip.status !== TripStatus.SEARCHING) return;
    const driverId = await this.redis.lpop(`dispatch:${tripId}:queue`);
    if (!driverId) {
      await this.prisma.trip.update({ where: { id: tripId }, data: { status: TripStatus.NO_DRIVERS } });
      this.events.toUser(trip.passengerId, 'trip.no_drivers', { tripId });
      return;
    }
    if (await this.redis.exists(`driver:busy:${driverId}`)) {
      await this.offerNext(tripId);
      return;
    }
    const offerSeconds = await this.settings.get('offerSeconds');
    await this.redis.set(`dispatch:${tripId}:offer`, driverId, 'EX', offerSeconds);
    this.events.toDriver(driverId, 'trip.offer', { trip, expiresInSeconds: offerSeconds });
    clearTimeout(this.timers.get(tripId));
    this.timers.set(tripId, setTimeout(() => void this.onTimeout(tripId, driverId), offerSeconds * 1000));
  }

  private async onTimeout(tripId: string, driverId: string): Promise<void> {
    this.timers.delete(tripId);
    if ((await this.offeredTo(tripId)) !== driverId) return;
    this.logger.debug(`Offer for ${tripId} to ${driverId} timed out`);
    await this.next(tripId);
  }
}
