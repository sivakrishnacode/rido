import { Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';

import { JobsService } from '../../core/jobs/jobs.service.js';
import { PrismaService } from '../../core/prisma/prisma.service.js';
import { RedisService } from '../../core/redis/redis.service.js';
import type { Trip } from '../../generated/prisma/client.js';
import { CancelCode, CancelledBy, TripStatus, type VehicleKind, WomenDriverPref } from '../../generated/prisma/enums.js';
import { DEL_IF_EQUALS, DriverLocationService } from '../drivers/driver-location.service.js';
import { applyWomenPref, womenAmong } from '../drivers/women-drivers.js';
import { roadKm } from '../geo/eta-model.js';
import { NotifierService } from '../notifications/notifier.service.js';
import { EtaService } from '../maps/eta.service.js';
import { TripEventsService } from '../realtime/trip-events.service.js';
import { SettingsService } from '../settings/settings.service.js';
import { assignBatch, BatchRequest } from './batch-assign.js';
import { searchRadiusAt, searchWindowMs } from './search-radius.js';

const PENDING_KEY = 'dispatch:pending';
const LOCK_KEY = 'dispatch:lock';
const SWEEP_LOCK_KEY = 'dispatch:sweep:lock';
/** The offer key outlives the offer timer so the timeout handler still sees whose offer it was. */
const OFFER_GRACE_S = 5;
/** Durable jobs (see JobsService): an offer's timeout, and the next search when the queue ran out. */
export const OFFER_EXPIRE_JOB = 'offer.expire';
export const RESEARCH_JOB = 'dispatch.research';
/** Out of candidates: search again after this long (drivers who timed out may be offered again). */
const RESEARCH_AFTER_MS = 4_000;
const SWEEP_EVERY_MS = 15_000;

/**
 * Uber-style dispatch:
 * 1. Bookings wait in a short batch window (`batchWindowMs`, default 2 s).
 * 2. For each booking, drivers are found by H3 rings around the pickup (pickup hexagon, then neighbours…), for the
 *    booked vehicle and any the passenger added ("Book any", [widen]). The radius grows from `searchRadiusKm` to
 *    `maxSearchRadiusKm` over `searchExpandSeconds` (see search-radius.ts).
 * 3. Candidates are ranked by road ETA (cached per hex pair), not straight-line distance. Butterfly trips keep only
 *    women drivers (ONLY) or give them a head start (PREFERRED), see women-drivers.ts.
 * 4. The whole batch is assigned together so two riders never get the same driver.
 * 5. Each driver gets `offerSeconds` to accept; decline/timeout moves to the next in that trip's queue.
 * 6. Out of candidates → search again every few seconds (a driver who let the offer time out can get it again; one who
 *    declined can't) until [searchWindowMs] has passed since the search started (or a vehicle was added), then
 *    NO_DRIVERS.
 * Offer timeouts and re-searches are durable jobs in Redis ([JobsService]), so an API restart doesn't lose them. A
 * sweep still re-queues or closes searching trips that fell through the cracks.
 * A Redis lock makes only one API instance run a batch at a time.
 */
@Injectable()
export class DispatchService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(DispatchService.name);
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
    private readonly jobs: JobsService,
  ) {}

  async onModuleInit(): Promise<void> {
    this.jobs.register<{ driverId: string }>(OFFER_EXPIRE_JOB, (job) => this.onTimeout(job.id, job.payload.driverId));
    this.jobs.register(RESEARCH_JOB, async (job) => void (await this.redis.sadd(PENDING_KEY, job.id)));
    const windowMs = await this.settings.get('batchWindowMs');
    this.ticker = setInterval(() => void this.tick(), Math.max(250, windowMs));
    this.sweeper = setInterval(() => void this.sweep().catch((e: Error) => this.logger.warn(`Sweep failed: ${e.message}`)), SWEEP_EVERY_MS);
  }

  onModuleDestroy(): void {
    if (this.ticker) clearInterval(this.ticker);
    if (this.sweeper) clearInterval(this.sweeper);
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
    // Only while it is still this trip's offer: the driver may already have one for another trip.
    if (driverId) await this.redis.eval(DEL_IF_EQUALS, 1, `dispatch:driver:${driverId}:offer`, tripId);
    await this.redis.del(`dispatch:${tripId}:offer`);
    await this.jobs.cancel(OFFER_EXPIRE_JOB, tripId);
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
    await this.jobs.cancel(RESEARCH_JOB, tripId);
    await this.redis.srem(PENDING_KEY, tripId);
    await this.clearOffer(tripId);
    await this.redis.del(
      `dispatch:${tripId}:queue`,
      `dispatch:${tripId}:declined`,
      `dispatch:${tripId}:offered`,
      `dispatch:${tripId}:since`,
    );
  }

  /**
   * The passenger added a vehicle to a searching trip: search again now (without cutting short an open offer) and
   * give the search its full time again from here.
   */
  async widen(tripId: string): Promise<void> {
    await this.redis.set(`dispatch:${tripId}:since`, String(Date.now()), 'EX', 900);
    if (await this.offeredTo(tripId)) {
      // The next search runs when this offer is answered or times out; queue one so the new vehicle joins then.
      await this.redis.sadd(PENDING_KEY, tripId);
      return;
    }
    await this.jobs.cancel(RESEARCH_JOB, tripId);
    await this.redis.sadd(PENDING_KEY, tripId);
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
        // A driver is looking at this trip right now (re-queued by [widen]): the fresh queue waits for their answer.
        const open = await this.offeredTo(trip.id);
        if (open) {
          await this.redis.lrem(key, 0, open);
          continue;
        }
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
    const radiusKm = searchRadiusAt(Date.now() - trip.createdAt.getTime(), s);
    const kinds: VehicleKind[] = [trip.vehicleKind, ...trip.alsoKinds.filter((k) => k !== trip.vehicleKind)];
    const [perKind, declined] = await Promise.all([
      Promise.all(
        kinds.map(async (kind) =>
          (await this.location.nearby({ kind, ...pickup, radiusKm, limit: s.maxCandidates * 2 })).map((d) => ({ ...d, kind })),
        ),
      ),
      this.redis.smembers(`dispatch:${trip.id}:declined`),
    ]);
    const nearby = perKind.flat().filter((d) => !declined.includes(d.driverId));
    const withEta = await Promise.all(
      nearby.map(async (d) => ({
        driverId: d.driverId,
        etaMin: await this.eta.minutes({ from: d, to: pickup, vehicleKind: d.kind, useRoad: s.useRoadEta }),
      })),
    );
    const women = trip.womenDriver === WomenDriverPref.NONE ? new Set<string>() : await womenAmong(this.prisma, withEta.map((d) => d.driverId));
    const candidates = applyWomenPref(withEta, trip.womenDriver, women)
      .sort((a, b) => a.etaMin - b.etaMin)
      .slice(0, s.maxCandidates);
    return { tripId: trip.id, createdAt: trip.createdAt, candidates };
  }

  private async offerNext(tripId: string, opts: { searchFoundNobody?: boolean } = {}): Promise<void> {
    const trip = await this.prisma.trip.findUnique({ where: { id: tripId } });
    if (!trip || trip.status !== TripStatus.SEARCHING) return;
    const driverId = await this.redis.lpop(`dispatch:${tripId}:queue`);
    if (!driverId) return this.searchAgainOrGiveUp(trip, opts.searchFoundNobody ?? false);
    const offerSeconds = await this.settings.get('offerSeconds');
    // One open offer per driver: a driver on a trip, or still deciding on another request, is skipped (they come
    // back in a later search if still near).
    const isFree =
      !(await this.redis.exists(`driver:busy:${driverId}`)) &&
      (await this.redis.set(`dispatch:driver:${driverId}:offer`, tripId, 'EX', offerSeconds + OFFER_GRACE_S, 'NX')) === 'OK';
    if (!isFree) {
      await this.offerNext(tripId);
      return;
    }
    await this.redis.set(`dispatch:${tripId}:offer`, driverId, 'EX', offerSeconds + OFFER_GRACE_S);
    await this.redis.set(`dispatch:${tripId}:offered`, '1', 'EX', 900);
    const details = await this.offerDetails(trip, driverId);
    this.events.toDriver(driverId, 'trip.offer', { ...details, expiresInSeconds: offerSeconds });
    // Also as a push: the driver app may be in the background or killed.
    void this.notifier.offer({ driverId, trip, pickupEtaMin: details.pickupEtaMin, expiresInSeconds: offerSeconds });
    await this.jobs.schedule(OFFER_EXPIRE_JOB, tripId, Date.now() + offerSeconds * 1000, { driverId });
  }

  /** What the driver sees on the request card: the trip (without the OTP), the customer and the pickup distance. */
  async offerDetails(booked: Trip, driverId: string): Promise<OfferDetails> {
    const pickup = { lat: booked.pickupLat, lng: booked.pickupLng };
    const [passenger, at, useRoad, driver] = await Promise.all([
      this.prisma.user.findUnique({ where: { id: booked.passengerId }, select: { name: true, phone: true, identityStatus: true } }),
      this.location.position(driverId),
      this.settings.get('useRoadEta'),
      this.prisma.driver.findUnique({ where: { id: driverId }, select: { vehicleKind: true } }),
    ]);
    // "Book any": a driver of an added vehicle sees the trip as their vehicle, at its fare.
    const trip = asVehicle(booked, driver?.vehicleKind);
    return {
      trip: { ...trip, otp: '' },
      // Booked for someone else: the driver sees and calls the rider; the account holder is "booked by".
      passenger: booked.riderName
        ? { name: booked.riderName, phone: booked.riderPhone ?? '', isVerified: false, bookedBy: passenger?.name ?? undefined }
        : { name: passenger?.name ?? 'Rido customer', phone: passenger?.phone ?? '', isVerified: passenger?.identityStatus === 'APPROVED' },
      pickupKm: at ? Math.round(roadKm(at, pickup) * 10) / 10 : null,
      pickupEtaMin: at ? await this.eta.minutes({ from: at, to: pickup, vehicleKind: trip.vehicleKind, useRoad }) : null,
    };
  }

  /** Search time left is counted from the booking, or from the last vehicle the passenger added. */
  private async searchedLongEnough(trip: Trip): Promise<boolean> {
    const [offered, since, s] = await Promise.all([
      this.redis.exists(`dispatch:${trip.id}:offered`),
      this.redis.get(`dispatch:${trip.id}:since`),
      this.settings.all(),
    ]);
    const from = Math.max(trip.createdAt.getTime(), Number(since ?? 0));
    return Date.now() - from >= searchWindowMs(offered === 1, s);
  }

  /**
   * Nobody left in the queue: search again shortly, or end the search once it has run long enough. A fresh search
   * that finds nobody but drivers who already declined ends it right away once the radius can't widen any more and
   * no other vehicle was added (they said no; waiting helps nobody).
   */
  private async searchAgainOrGiveUp(trip: Trip, searchFoundNobody: boolean): Promise<void> {
    if (searchFoundNobody && (await this.redis.scard(`dispatch:${trip.id}:declined`)) > 0) {
      // Only drivers who said no are in range: wait while the radius still widens, else end it now.
      const s = await this.settings.all();
      const atMax = searchRadiusAt(Date.now() - trip.createdAt.getTime(), s) >= Math.max(s.searchRadiusKm, s.maxSearchRadiusKm);
      if (atMax && trip.alsoKinds.length === 0) return this.giveUp(trip);
    }
    if (!(await this.searchedLongEnough(trip))) {
      await this.jobs.schedule(RESEARCH_JOB, trip.id, Date.now() + RESEARCH_AFTER_MS);
      return;
    }
    await this.giveUp(trip);
  }

  private async giveUp(trip: Trip): Promise<void> {
    const { count } = await this.prisma.trip.updateMany({
      where: { id: trip.id, status: TripStatus.SEARCHING },
      data: { status: TripStatus.NO_DRIVERS, cancelledBy: CancelledBy.SYSTEM, cancelCode: CancelCode.NO_DRIVERS, cancelledAt: new Date() },
    });
    await this.stop(trip.id);
    if (count === 0) return;
    this.events.toUser(trip.passengerId, 'trip.no_drivers', { tripId: trip.id });
    this.notifier.tripChanged({ ...trip, status: TripStatus.NO_DRIVERS }, 'SYSTEM');
  }

  /**
   * Safety net (one instance at a time): a SEARCHING trip with no open offer, no pending batch and no scheduled
   * re-search fell through the cracks (e.g. its offer key expired while the API was down) → queue it again, or end
   * it if it has searched long enough.
   */
  async sweep(): Promise<void> {
    if (!(await this.redis.set(SWEEP_LOCK_KEY, '1', 'PX', SWEEP_EVERY_MS - 1_000, 'NX'))) return;
    const searching = await this.prisma.trip.findMany({ where: { status: TripStatus.SEARCHING } });
    for (const trip of searching) {
      const [offer, pending, retry] = await Promise.all([
        this.offeredTo(trip.id),
        this.redis.sismember(PENDING_KEY, trip.id),
        this.jobs.scheduledAt(RESEARCH_JOB, trip.id),
      ]);
      if (offer || pending || retry) continue;
      if (await this.searchedLongEnough(trip)) await this.giveUp(trip);
      else await this.redis.sadd(PENDING_KEY, trip.id);
    }
  }

  private async onTimeout(tripId: string, driverId: string): Promise<void> {
    if ((await this.offeredTo(tripId)) !== driverId) return;
    this.logger.debug(`Offer for ${tripId} to ${driverId} timed out`);
    await this.next(tripId);
  }
}

/**
 * [trip] as matched with a driver of [kind]: an added vehicle ("Book any") takes its own quote from `alsoFares`;
 * the booked vehicle (or an unknown one) leaves the trip as it is.
 */
export function asVehicle(trip: Trip, kind: VehicleKind | undefined): Trip {
  if (!kind || kind === trip.vehicleKind || !trip.alsoKinds.includes(kind)) return trip;
  const quote = (trip.alsoFares as Record<string, { total: number }> | null)?.[kind];
  if (!quote) return trip;
  return { ...trip, vehicleKind: kind, fare: quote, fareTotal: quote.total };
}

export interface OfferDetails {
  trip: Trip;
  /** isVerified: the rider passed the optional Didit check (a badge on the request card). */
  /** The rider: the account holder, or who they booked for ([bookedBy] = the account holder's name). */
  passenger: { name: string; phone: string; isVerified: boolean; bookedBy?: string };
  pickupKm: number | null;
  pickupEtaMin: number | null;
}
