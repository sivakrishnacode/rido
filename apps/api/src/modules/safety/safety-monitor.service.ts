import { Injectable, Logger } from '@nestjs/common';

import { PrismaService } from '../../core/prisma/prisma.service.js';
import { RedisService } from '../../core/redis/redis.service.js';
import type { Prisma, Trip } from '../../generated/prisma/client.js';
import { SafetyEventKind, TripKind } from '../../generated/prisma/enums.js';
import type { LocationFix } from '../drivers/location-fix.js';
import { NotifierService } from '../notifications/notifier.service.js';
import { SettingsService } from '../settings/settings.service.js';
import { decodePolyline, type LatLngLiteral } from '../maps/polyline.js';
import { isNightIst } from './night-window.js';
import { NIGHT_DEVIATION_PUSH_M, stepDeviation } from './route-deviation.js';
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

/** A route deviation is recorded at most once per this many minutes (and pushed at most once per it). */
export const DEVIATION_DEDUPE_MIN = 10;

/** The `safety.check` socket payload for [c]. */
export function safetyCheckPayload(c: SafetyCheck): { tripId: string; kind: string; eventId: string; title: string; message: string } {
  return { tripId: c.tripId, kind: c.kind, eventId: c.eventId, title: c.title, message: c.message };
}

const keys = (tripId: string) => ({
  state: `trip:safety:${tripId}`,
  stopAlert: `trip:safety:stop:${tripId}`,
  devAlert: `trip:safety:dev:${tripId}`,
  devPush: `trip:safety:devpush:${tripId}`,
});

/** Decoded routes by trip (decoding per fix would be wasteful); small, oldest dropped first. */
const ROUTE_MEMO_MAX = 500;

/** What [SafetyMonitorService.rideStarted] stores per trip (strings in a Redis hash). */
type RideState = Record<string, string>;

const num = (v: string | undefined): number | null => (v === undefined || v === '' ? null : Number.isFinite(Number(v)) ? Number(v) : null);

/**
 * Safety checks on the driver's GPS while a ride is on (IN_PROGRESS / PICKED_UP), per fix and without a database
 * read: `rideStarted` puts what the checks need in the Redis hash `trip:safety:<id>` (passenger, pickup, drop, the
 * quoted route, the stop anchor, the off-route count); `onFixes` runs every fix through the stop detector and the
 * route-deviation counter and, on a hit, records a `SafetyEvent` and pushes the passenger "Is everything OK?" (a
 * stop always, a deviation only at night and more than 1 km off; rides only, parcels just get the event). Alerts are
 * deduped in Redis (`trip:safety:stop:<id>` per `stopDedupeMin`, `trip:safety:dev[push]:<id>` per 10 min). Never
 * throws into the GPS path.
 */
@Injectable()
export class SafetyMonitorService {
  private readonly logger = new Logger(SafetyMonitorService.name);
  private readonly routes = new Map<string, { encoded: string; points: LatLngLiteral[] }>();

  constructor(
    private readonly redis: RedisService,
    private readonly prisma: PrismaService,
    private readonly notifier: NotifierService,
    private readonly settings: SettingsService,
  ) {}

  /**
   * The ride started: remember what the checks need (the quoted route too, when the trip has one). A night ride
   * whose passenger doesn't auto-share gets "Share your trip with a friend?"; that check is returned for the socket.
   */
  async rideStarted(trip: Trip): Promise<SafetyCheck | null> {
    const k = keys(trip.id);
    const state: RideState = {
      pid: trip.passengerId,
      kind: trip.kind,
      plat: String(trip.pickupLat),
      plng: String(trip.pickupLng),
      dlat: String(trip.dropLat),
      dlng: String(trip.dropLng),
      route: trip.routePolyline ?? '',
    };
    await this.redis.multi().del(k.state, k.devAlert, k.devPush).hset(k.state, state).expire(k.state, SAFETY_STATE_TTL_S).exec();
    const s = await this.settings.all();
    if (trip.kind !== TripKind.RIDE || !isNightIst(trip.startedAt ?? new Date(), s.nightStartHour, s.nightEndHour)) return null;
    const user = await this.prisma.user.findUnique({ where: { id: trip.passengerId }, select: { autoShareTrips: true } });
    // With auto-share on, the app already opens the share sheet at the start.
    if (user?.autoShareTrips) return null;
    return this.alert({
      tripId: trip.id,
      passengerId: trip.passengerId,
      isRide: true,
      kind: SafetyEventKind.NIGHT_CHECK,
      checkKind: 'NIGHT_START',
      payload: { check: 'NIGHT_START' },
      title: 'Share your trip with a friend?',
      message: "It's late. Send someone a live link to your ride",
    });
  }

  /** The trip ended (or changed driver): drop the state and dedupe keys. */
  async clear(tripId: string): Promise<void> {
    const k = keys(tripId);
    this.routes.delete(tripId);
    await this.redis.del(k.state, k.stopAlert, k.devAlert, k.devPush);
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
    const route = this.route(tripId, state.route);
    let devN = num(state.devN) ?? 0;
    let deviation: { lat: number; lng: number; offM: number; ts: number } | null = null;
    for (const fix of fixes) {
      const step = stepStop(anchor, fix, ends, { radiusM: s.stopRadiusM, minutes: s.stopMinutes });
      anchor = step.anchor;
      if (step.isStop) stop = { at: step.anchor, stoppedMs: step.stoppedMs };
      if (route) {
        const dev = stepDeviation(devN, fix, route, s.deviationM);
        devN = dev.count;
        // The farthest point of the current deviation in this upload.
        if (dev.isDeviation && (!deviation || dev.offM > deviation.offM)) deviation = { lat: fix.lat, lng: fix.lng, offM: dev.offM, ts: fix.ts };
      }
    }
    const saved: Record<string, string> = { devN: String(devN) };
    if (anchor) Object.assign(saved, { aLat: String(anchor.lat), aLng: String(anchor.lng), aT: String(anchor.t) });
    await this.redis.hset(k.state, saved);
    const checks: SafetyCheck[] = [];
    if (deviation) {
      const check = await this.onDeviation(tripId, state, deviation, s);
      if (check) checks.push(check);
    }
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

  /**
   * A deviation (3+ fixes off the quoted route): recorded once per [DEVIATION_DEDUPE_MIN]; at night, one more than
   * [NIGHT_DEVIATION_PUSH_M] off also asks the passenger "Is everything OK?" (once per the same time).
   */
  private async onDeviation(tripId: string, state: RideState, d: { lat: number; lng: number; offM: number; ts: number }, s: { nightStartHour: number; nightEndHour: number }): Promise<SafetyCheck | null> {
    const k = keys(tripId);
    const ttl = DEVIATION_DEDUPE_MIN * 60;
    const isNight = isNightIst(new Date(d.ts), s.nightStartHour, s.nightEndHour);
    const isRide = state.kind === TripKind.RIDE;
    const payload = { lat: d.lat, lng: d.lng, offM: d.offM, night: isNight };
    if (isRide && isNight && d.offM > NIGHT_DEVIATION_PUSH_M && (await this.redis.set(k.devPush, '1', 'EX', ttl, 'NX')) === 'OK') {
      await this.redis.set(k.devAlert, '1', 'EX', ttl);
      return this.alert({
        tripId,
        passengerId: state.pid,
        isRide,
        kind: SafetyEventKind.DEVIATION,
        checkKind: 'DEVIATION',
        payload,
        title: 'Your driver changed route. Is everything OK?',
        message: `Your ride is ${(d.offM / 1000).toFixed(1)} km off the planned route. Tap if you need help`,
      });
    }
    if ((await this.redis.set(k.devAlert, '1', 'EX', ttl, 'NX')) !== 'OK') return null;
    await this.prisma.safetyEvent.create({ data: { tripId, kind: SafetyEventKind.DEVIATION, payload: { ...payload, pushed: false } } });
    this.logger.log(`Safety DEVIATION on trip ${tripId} (${d.offM} m)`);
    return null;
  }

  /** The decoded quoted route of [tripId] (memoised), or null without one. */
  private route(tripId: string, encoded: string | undefined): LatLngLiteral[] | null {
    if (!encoded) return null;
    const hit = this.routes.get(tripId);
    if (hit?.encoded === encoded) return hit.points;
    const points = decodePolyline(encoded);
    if (points.length < 2) return null;
    if (this.routes.size >= ROUTE_MEMO_MAX) this.routes.delete(this.routes.keys().next().value as string);
    this.routes.set(tripId, { encoded, points });
    return points;
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
