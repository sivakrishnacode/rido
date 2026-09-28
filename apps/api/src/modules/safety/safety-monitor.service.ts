import { Injectable, Logger } from '@nestjs/common';

import { PrismaService } from '../../core/prisma/prisma.service.js';
import { RedisService } from '../../core/redis/redis.service.js';
import type { Prisma, Trip } from '../../generated/prisma/client.js';
import { SafetyEventKind, TripKind } from '../../generated/prisma/enums.js';
import type { LocationFix } from '../drivers/location-fix.js';
import { NotifierService } from '../notifications/notifier.service.js';
import { SettingsService } from '../settings/settings.service.js';
import { type StopAnchor, stepStop } from './stop-detector.js';

/** The ride state outlives the longest trip; deleted when the trip ends. */
export const SAFETY_STATE_TTL_S = 12 * 3600;

/** Socket event to the passenger's user room: show the "Is everything OK?" sheet. */
export const SAFETY_CHECK_EVENT = 'safety.check';

/** A check the passenger should answer ("I'm OK" / "Get help"): pushed, and emitted on the socket by the caller. */
export interface SafetyCheck {
  readonly passengerId: string;
  readonly tripId: string;
  /** STOP, DEVIATION, NIGHT_START, SAFE_ARRIVAL. */
  readonly kind: string;
  readonly eventId: string;
  readonly title: string;
  readonly message: string;
}

const keys = (tripId: string) => ({
  state: `trip:safety:${tripId}`,
  stopAlert: `trip:safety:stop:${tripId}`,
});

/** What [SafetyMonitorService.rideStarted] stores per trip (strings in a Redis hash). */
type RideState = Record<string, string>;

const num = (v: string | undefined): number | null => (v === undefined || v === '' ? null : Number.isFinite(Number(v)) ? Number(v) : null);

/**
 * Safety checks on the driver's GPS while a ride is on (IN_PROGRESS / PICKED_UP), per fix and without a database
 * read: `rideStarted` puts what the checks need in the Redis hash `trip:safety:<id>` (passenger, pickup, drop, the
 * stop anchor); `onFixes` runs every fix through the detectors and, on a hit, records a `SafetyEvent` and pushes the
 * passenger "Is everything OK?" (rides only; parcels just get the event). Alerts are deduped in Redis
 * (`trip:safety:stop:<id>`, one per `stopDedupeMin`). Never throws into the GPS path.
 */
@Injectable()
export class SafetyMonitorService {
  private readonly logger = new Logger(SafetyMonitorService.name);

  constructor(
    private readonly redis: RedisService,
    private readonly prisma: PrismaService,
    private readonly notifier: NotifierService,
    private readonly settings: SettingsService,
  ) {}

  /** The ride started: remember what the checks need. */
  async rideStarted(trip: Trip): Promise<void> {
    const k = keys(trip.id);
    const state: RideState = {
      pid: trip.passengerId,
      kind: trip.kind,
      plat: String(trip.pickupLat),
      plng: String(trip.pickupLng),
      dlat: String(trip.dropLat),
      dlng: String(trip.dropLng),
    };
    await this.redis.multi().del(k.state).hset(k.state, state).expire(k.state, SAFETY_STATE_TTL_S).exec();
  }

  /** The trip ended (or changed driver): drop the state and dedupe keys. */
  async clear(tripId: string): Promise<void> {
    const k = keys(tripId);
    await this.redis.del(k.state, k.stopAlert);
  }

  /** Runs [fixes] (oldest first) through the checks; the checks to show the passenger (usually none). */
  async onFixes(tripId: string, fixes: readonly LocationFix[]): Promise<SafetyCheck[]> {
    try {
      return await this.check(tripId, fixes);
    } catch (e) {
      this.logger.warn(`Safety check on ${tripId} failed: ${(e as Error).message}`);
      return [];
    }
  }

  private async check(tripId: string, fixes: readonly LocationFix[]): Promise<SafetyCheck[]> {
    const k = keys(tripId);
    const state = (await this.redis.hgetall(k.state)) as RideState;
    if (!state.pid || !fixes.length) return [];
    const s = await this.settings.all();
    const ends = { pickup: { lat: Number(state.plat), lng: Number(state.plng) }, drop: { lat: Number(state.dlat), lng: Number(state.dlng) } };
    const aLat = num(state.aLat);
    const aLng = num(state.aLng);
    const aT = num(state.aT);
    let anchor: StopAnchor | null = aLat !== null && aLng !== null && aT !== null ? { lat: aLat, lng: aLng, t: aT } : null;
    let stop: { at: StopAnchor; stoppedMs: number } | null = null;
    for (const fix of fixes) {
      const step = stepStop(anchor, fix, ends, { radiusM: s.stopRadiusM, minutes: s.stopMinutes });
      anchor = step.anchor;
      if (step.isStop) stop = { at: step.anchor, stoppedMs: step.stoppedMs };
    }
    if (anchor) await this.redis.hset(k.state, { aLat: String(anchor.lat), aLng: String(anchor.lng), aT: String(anchor.t) });
    const checks: SafetyCheck[] = [];
    // One alert per stopDedupeMin, however long the stop lasts.
    if (stop && (await this.redis.set(k.stopAlert, '1', 'EX', Math.max(60, s.stopDedupeMin * 60), 'NX')) === 'OK') {
      const minutes = Math.floor(stop.stoppedMs / 60_000);
      const check = await this.alert({
        tripId,
        passengerId: state.pid,
        isRide: state.kind === TripKind.RIDE,
        kind: SafetyEventKind.STOP,
        checkKind: 'STOP',
        payload: { lat: stop.at.lat, lng: stop.at.lng, since: new Date(stop.at.t).toISOString(), minutes },
        title: 'Is everything OK?',
        message: `Your ride has been stopped for ${minutes} min. Tap if you need help`,
      });
      if (check) checks.push(check);
    }
    return checks;
  }

  /** Records the event and, for rides, pushes the passenger; the check for the socket (null for parcels). */
  private async alert(p: {
    tripId: string;
    passengerId: string;
    isRide: boolean;
    kind: SafetyEventKind;
    checkKind: string;
    payload: Record<string, unknown>;
    title: string;
    message: string;
  }): Promise<SafetyCheck | null> {
    const event = await this.prisma.safetyEvent.create({
      data: { tripId: p.tripId, kind: p.kind, payload: { ...p.payload, pushed: p.isRide } as Prisma.InputJsonValue },
    });
    this.logger.log(`Safety ${p.checkKind} on trip ${p.tripId}`);
    if (!p.isRide) return null;
    const check: SafetyCheck = { passengerId: p.passengerId, tripId: p.tripId, kind: p.checkKind, eventId: event.id, title: p.title, message: p.message };
    void this.notifier.safetyCheck(check);
    return check;
  }
}
