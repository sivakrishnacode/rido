import { Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';

import { PrismaService } from '../../core/prisma/prisma.service.js';
import { RedisService } from '../../core/redis/redis.service.js';
import type { Trip } from '../../generated/prisma/client.js';
import { TripStatus } from '../../generated/prisma/enums.js';
import { DriverLocationService } from '../drivers/driver-location.service.js';
import { roadKm } from '../geo/eta-model.js';
import { NotifierService } from '../notifications/notifier.service.js';
import { EtaService } from '../maps/eta.service.js';
import { TripEventsService } from '../realtime/trip-events.service.js';
import { SettingsService } from '../settings/settings.service.js';
import { assignBatch, BatchRequest } from './batch-assign.js';

const PENDING_KEY = 'dispatch:pending';
const LOCK_KEY = 'dispatch:lock';
const SWEEP_LOCK_KEY = 'dispatch:sweep:lock';
/** The offer key outlives the offer timer so the timeout handler still sees whose offer it was. */
const OFFER_GRACE_S = 5;
/** Out of candidates: search again after this long (drivers who timed out may be offered again). */
const RESEARCH_AFTER_MS = 4_000;
/** Keep searching this long when some driver was offered the trip, or when nobody was nearby at all. */
const SEARCH_FOR_MS = 90_000;
const SEARCH_EMPTY_FOR_MS = 30_000;
const SWEEP_EVERY_MS = 15_000;

/**
 * Uber-style dispatch:
 * 1. Bookings wait in a short batch window (`batchWindowMs`, default 2 s).
 * 2. For each booking, drivers are found by H3 rings around the pickup (pickup hexagon, then neighbours…).
 * 3. Candidates are ranked by road ETA (cached per hex pair), not straight-line distance.
 * 4. The whole batch is assigned together so two riders never get the same driver.
 * 5. Each driver gets `offerSeconds` to accept; decline/timeout moves to the next in that trip's queue.
 * 6. Out of candidates → search again every few seconds (a driver who let the offer time out can get it again; one who
 *    declined can't) until [SEARCH_FOR_MS] (or [SEARCH_EMPTY_FOR_MS] if nobody was nearby), then NO_DRIVERS.
 *    A sweep re-queues or closes searching trips that lost their timers (e.g. after a restart).
 * A Redis lock makes only one API instance run a batch at a time.
 */
@Injectable()
export class DispatchService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(DispatchService.name);
  private readonly timers = new Map<string, NodeJS.Timeout>();
  private ticker: NodeJS.Timeout | null = null;
  private sweeper: NodeJS.Timeout | null = null;
  private isTicking = false;

  constructor(
    private readonly redis: RedisService,
    private readonly prisma: PrismaService,
    private readonly location: DriverLocationService,
    private readonly events: TripEventsService,
    private readonly settings: SettingsService,
    private readonly eta: EtaService,
    private readonly notifier: NotifierService,
  ) {}

  async onModuleInit(): Promise<void> {
    const windowMs = await this.settings.get('batchWindowMs');
    this.ticker = setInterval(() => void this.tick(), Math.max(250, windowMs));
    this.sweeper = setInterval(() => void this.sweep().catch((e: Error) => this.logger.warn(`Sweep failed: ${e.message}`)), SWEEP_EVERY_MS);
  }

  onModuleDestroy(): void {
    if (this.ticker) clearInterval(this.ticker);
    if (this.sweeper) clearInterval(this.sweeper);
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

  /** The trip currently offered to [driverId] (lets the app recover an offer it missed on the socket). */
  async currentOffer(driverId: string): Promise<(OfferDetails & { expiresInSeconds: number }) | null> {
    const tripId = await this.redis.get(`dispatch:driver:${driverId}:offer`);
    if (!tripId || (await this.offeredTo(tripId)) !== driverId) return null;
    const trip = await this.prisma.trip.findUnique({ where: { id: tripId } });
    if (!trip || trip.status !== TripStatus.SEARCHING) return null;
    const ttl = (await this.redis.ttl(`dispatch:${tripId}:offer`)) - OFFER_GRACE_S;
    if (ttl < 1) return null;
    return { ...(await this.offerDetails(trip, driverId)), expiresInSeconds: ttl };
  }

  private async clearOffer(tripId: string): Promise<void> {
    const driverId = await this.offeredTo(tripId);
    if (driverId) await this.redis.del(`dispatch:driver:${driverId}:offer`);
    await this.redis.del(`dispatch:${tripId}:offer`);
  }

  /** The driver said no: never offer them this trip again, try the next candidate. */
  async decline(tripId: string, driverId: string): Promise<void> {
    await this.redis.multi().sadd(`dispatch:${tripId}:declined`, driverId).expire(`dispatch:${tripId}:declined`, 900).exec();
    await this.next(tripId);
  }

  /** Driver declined or the offer timed out: try the next candidate. */
  async next(tripId: string): Promise<void> {
    await this.clearOffer(tripId);
    await this.offerNext(tripId);
  }

  /** Stops dispatching (trip accepted or cancelled). */
  async stop(tripId: string): Promise<void> {
    clearTimeout(this.timers.get(tripId));
    this.timers.delete(tripId);
    await this.redis.srem(PENDING_KEY, tripId);
    await this.clearOffer(tripId);
    await this.redis.del(`dispatch:${tripId}:queue`, `dispatch:${tripId}:declined`, `dispatch:${tripId}:offered`, `dispatch:${tripId}:retry`);
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
        await this.offerNext(trip.id, { searchFoundNobody: queue.length === 0 });
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
    const [found, declined] = await Promise.all([
      this.location.nearby({ kind: trip.vehicleKind, ...pickup, radiusKm: s.searchRadiusKm, limit: s.maxCandidates * 2 }),
      this.redis.smembers(`dispatch:${trip.id}:declined`),
    ]);
    const nearby = found.filter((d) => !declined.includes(d.driverId));
    const withEta = await Promise.all(
      nearby.map(async (d) => ({
        driverId: d.driverId,
        etaMin: await this.eta.minutes({ from: d, to: pickup, vehicleKind: trip.vehicleKind, useRoad: s.useRoadEta }),
      })),
    );
    const candidates = withEta.sort((a, b) => a.etaMin - b.etaMin).slice(0, s.maxCandidates);
    return { tripId: trip.id, createdAt: trip.createdAt, candidates };
  }

  private async offerNext(tripId: string, opts: { searchFoundNobody?: boolean } = {}): Promise<void> {
    const trip = await this.prisma.trip.findUnique({ where: { id: tripId } });
    if (!trip || trip.status !== TripStatus.SEARCHING) return;
    const driverId = await this.redis.lpop(`dispatch:${tripId}:queue`);
    if (!driverId) return this.searchAgainOrGiveUp(trip, opts.searchFoundNobody ?? false);
    if (await this.redis.exists(`driver:busy:${driverId}`)) {
      await this.offerNext(tripId);
      return;
    }
    const offerSeconds = await this.settings.get('offerSeconds');
    await this.redis.set(`dispatch:${tripId}:offer`, driverId, 'EX', offerSeconds + OFFER_GRACE_S);
    await this.redis.set(`dispatch:driver:${driverId}:offer`, tripId, 'EX', offerSeconds + OFFER_GRACE_S);
    await this.redis.set(`dispatch:${tripId}:offered`, '1', 'EX', 900);
    const details = await this.offerDetails(trip, driverId);
    this.events.toDriver(driverId, 'trip.offer', { ...details, expiresInSeconds: offerSeconds });
    // Also as a push: the driver app may be in the background or killed.
    void this.notifier.offer({ driverId, trip, pickupEtaMin: details.pickupEtaMin, expiresInSeconds: offerSeconds });
    clearTimeout(this.timers.get(tripId));
    this.timers.set(tripId, setTimeout(() => void this.onTimeout(tripId, driverId), offerSeconds * 1000));
  }

  /** What the driver sees on the request card: the trip (without the OTP), the customer and the pickup distance. */
  async offerDetails(trip: Trip, driverId: string): Promise<OfferDetails> {
    const pickup = { lat: trip.pickupLat, lng: trip.pickupLng };
    const [passenger, at, useRoad] = await Promise.all([
      this.prisma.user.findUnique({ where: { id: trip.passengerId }, select: { name: true, phone: true } }),
      this.location.position(driverId),
      this.settings.get('useRoadEta'),
    ]);
    return {
      trip: { ...trip, otp: '' },
      passenger: { name: passenger?.name ?? 'Rido customer', phone: passenger?.phone ?? '' },
      pickupKm: at ? Math.round(roadKm(at, pickup) * 10) / 10 : null,
      pickupEtaMin: at ? await this.eta.minutes({ from: at, to: pickup, vehicleKind: trip.vehicleKind, useRoad }) : null,
    };
  }

  /**
   * Nobody left in the queue: search again shortly, or end the search once it has run long enough. A fresh search
   * that finds nobody but drivers who already declined ends it right away (they said no; waiting helps nobody).
   */
  private async searchAgainOrGiveUp(trip: Trip, searchFoundNobody: boolean): Promise<void> {
    if (searchFoundNobody && (await this.redis.scard(`dispatch:${trip.id}:declined`)) > 0) return this.giveUp(trip);
    const wasOffered = (await this.redis.exists(`dispatch:${trip.id}:offered`)) === 1;
    const age = Date.now() - trip.createdAt.getTime();
    if (age < (wasOffered ? SEARCH_FOR_MS : SEARCH_EMPTY_FOR_MS)) {
      await this.redis.set(`dispatch:${trip.id}:retry`, '1', 'PX', RESEARCH_AFTER_MS * 3);
      clearTimeout(this.timers.get(trip.id));
      this.timers.set(trip.id, setTimeout(() => void this.redis.sadd(PENDING_KEY, trip.id), RESEARCH_AFTER_MS));
      return;
    }
    await this.giveUp(trip);
  }

  private async giveUp(trip: Trip): Promise<void> {
    const { count } = await this.prisma.trip.updateMany({ where: { id: trip.id, status: TripStatus.SEARCHING }, data: { status: TripStatus.NO_DRIVERS } });
    await this.stop(trip.id);
    if (count === 0) return;
    this.events.toUser(trip.passengerId, 'trip.no_drivers', { tripId: trip.id });
    this.notifier.tripChanged({ ...trip, status: TripStatus.NO_DRIVERS }, 'SYSTEM');
  }

  /**
   * Safety net (one instance at a time): a SEARCHING trip with no open offer, no pending batch and no scheduled
   * re-search lost its timers (e.g. the API restarted) → queue it again, or end it if it has searched long enough.
   */
  async sweep(): Promise<void> {
    if (!(await this.redis.set(SWEEP_LOCK_KEY, '1', 'PX', SWEEP_EVERY_MS - 1_000, 'NX'))) return;
    const searching = await this.prisma.trip.findMany({ where: { status: TripStatus.SEARCHING } });
    for (const trip of searching) {
      const [offer, pending, retry] = await Promise.all([
        this.offeredTo(trip.id),
        this.redis.sismember(PENDING_KEY, trip.id),
        this.redis.exists(`dispatch:${trip.id}:retry`),
      ]);
      if (offer || pending || retry) continue;
      const wasOffered = (await this.redis.exists(`dispatch:${trip.id}:offered`)) === 1;
      if (Date.now() - trip.createdAt.getTime() >= (wasOffered ? SEARCH_FOR_MS : SEARCH_EMPTY_FOR_MS)) await this.giveUp(trip);
      else await this.redis.sadd(PENDING_KEY, trip.id);
    }
  }

  private async onTimeout(tripId: string, driverId: string): Promise<void> {
    this.timers.delete(tripId);
    if ((await this.offeredTo(tripId)) !== driverId) return;
    this.logger.debug(`Offer for ${tripId} to ${driverId} timed out`);
    await this.next(tripId);
  }
}

export interface OfferDetails {
  trip: Trip;
  passenger: { name: string; phone: string };
  pickupKm: number | null;
  pickupEtaMin: number | null;
}
