import { Injectable } from '@nestjs/common';

import { RedisService } from '../../core/redis/redis.service.js';
import type { LocationFix } from '../drivers/location-fix.js';
import { decodePoint, encodePoint, isAccurateEnough, type PathPhase, type PathSummary, summarizePath } from '../trips/trip-path.js';

/** Breadcrumbs outlive the longest trip; a trip that never ends leaves nothing behind for long. */
export const TRIP_TRACK_TTL_S = 12 * 3600;
/** Most points recorded per trip (≈ 8 h at one every 5 s); later ones are dropped. */
export const MAX_TRIP_POINTS = 6000;

const keys = (tripId: string) => ({
  phase: `trip:phase:${tripId}`,
  points: `trip:pts:${tripId}`,
  meta: `trip:ptmeta:${tripId}`,
});

/**
 * Per-trip GPS breadcrumbs in Redis (like Namma Yatri's per-driver waypoint list): `trip:phase:<id>` says which part
 * is recorded (`p` to the pickup from accept, `t` from start), `trip:pts:<id>` holds the points
 * (`ts,lat,lng,acc,mock,phase`), `trip:ptmeta:<id>` counts mock and too-inaccurate fixes. All expire after 12 h and
 * are deleted once the trip ends. Measured at completion by [summarizePath].
 */
@Injectable()
export class TripTrackService {
  constructor(private readonly redis: RedisService) {}

  /** Starts (or moves on to) recording [phase] for the trip. */
  async setPhase(tripId: string, phase: PathPhase): Promise<void> {
    await this.redis.set(keys(tripId).phase, phase, 'EX', TRIP_TRACK_TTL_S);
  }

  /** Records the driver's [fixes] on the trip they are on (nothing while no phase is set). */
  async append(tripId: string, fixes: readonly LocationFix[]): Promise<void> {
    const k = keys(tripId);
    const phase = (await this.redis.get(k.phase)) as PathPhase | null;
    if (phase !== 'p' && phase !== 't') return;
    const mocks = fixes.filter((f) => f.mock).length;
    const points = fixes.filter((f) => isAccurateEnough(f.acc)).map((f) => encodePoint({ ...f, phase }));
    const tx = this.redis.multi();
    if (points.length) {
      tx.rpush(k.points, ...points)
        .ltrim(k.points, 0, MAX_TRIP_POINTS - 1)
        .expire(k.points, TRIP_TRACK_TTL_S);
    }
    if (mocks) tx.hincrby(k.meta, 'mock', mocks);
    if (points.length < fixes.length) tx.hincrby(k.meta, 'inaccurate', fixes.length - points.length);
    tx.expire(k.meta, TRIP_TRACK_TTL_S);
    await tx.exec();
  }

  /** Measures what was recorded (nothing is deleted: see [clear]). */
  async summary(tripId: string): Promise<PathSummary> {
    const k = keys(tripId);
    const [raw, meta] = await Promise.all([this.redis.lrange(k.points, 0, -1), this.redis.hgetall(k.meta)]);
    const points = raw.map(decodePoint).filter((p) => p !== null);
    return summarizePath(points, Number(meta.mock ?? 0));
  }

  async clear(tripId: string): Promise<void> {
    const k = keys(tripId);
    await this.redis.del(k.phase, k.points, k.meta);
  }
}
