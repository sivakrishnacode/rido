import { Injectable, Logger } from '@nestjs/common';

import { RedisService } from '../../core/redis/redis.service.js';
import { EMPTY_STATS, idleSince, lastTripEndKey, onlineSinceKey, type OfferStats, RANK_BUCKET_TTL_S, RANK_WINDOW_DAYS, STAT_FIELDS, type StatEvent, statsKey, statsKeys, sumStats } from './driver-rank.js';

/**
 * Per-driver offer counters for ranking (trips/driver-rank.ts): one Redis hash per driver per UTC day
 * (`drv:stats:<id>:<yyyymmdd>`, 8-day TTL), read for a whole candidate batch in one pipeline. Counting never
 * blocks dispatch: a failed write is logged and dropped.
 */
@Injectable()
export class DriverOfferStatsService {
  private readonly logger = new Logger(DriverOfferStatsService.name);

  constructor(private readonly redis: RedisService) {}

  /** +1 to [event] for [driverId] today. */
  async record(driverId: string, event: StatEvent, now = Date.now()): Promise<void> {
    const key = statsKey(driverId, now);
    try {
      await this.redis.multi().hincrby(key, STAT_FIELDS[event], 1).expire(key, RANK_BUCKET_TTL_S).exec();
    } catch (e) {
      this.logger.warn(`Offer stat ${event} for ${driverId} not counted: ${(e as Error).message}`);
    }
  }

  /** 7-day counters and idle start of each of [driverIds], in one round trip. */
  async forDrivers(driverIds: readonly string[], now = Date.now()): Promise<Map<string, { stats: OfferStats; idleSince: number | null }>> {
    const out = new Map<string, { stats: OfferStats; idleSince: number | null }>();
    if (driverIds.length === 0) return out;
    const pipe = this.redis.pipeline();
    for (const id of driverIds) {
      for (const key of statsKeys(id, now)) pipe.hgetall(key);
      pipe.get(lastTripEndKey(id));
      pipe.get(onlineSinceKey(id));
    }
    const replies = (await pipe.exec()) ?? [];
    const per = RANK_WINDOW_DAYS + 2;
    driverIds.forEach((id, i) => {
      const r = replies.slice(i * per, (i + 1) * per).map(([err, v]) => (err ? null : v));
      out.set(id, {
        stats: sumStats(r.slice(0, RANK_WINDOW_DAYS) as (Record<string, string> | null)[]),
        idleSince: idleSince(r[RANK_WINDOW_DAYS] as string | null, r[RANK_WINDOW_DAYS + 1] as string | null),
      });
    });
    return out;
  }

  async forDriver(driverId: string, now = Date.now()): Promise<OfferStats> {
    return (await this.forDrivers([driverId], now)).get(driverId)?.stats ?? EMPTY_STATS;
  }
}
