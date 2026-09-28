import { HttpException, HttpStatus } from '@nestjs/common';

import type { RedisService } from '../../core/redis/redis.service.js';

/**
 * Fixed-window counter in Redis: throws 429 `RATE_LIMITED` once [key] was hit more than [limit] times in the
 * current [windowS] window. One INCR (+ EXPIRE on the first hit) per call.
 */
export async function rateLimit(redis: RedisService, key: string, limit: number, windowS: number): Promise<void> {
  const k = `rl:${key}`;
  const res = (await redis.multi().incr(k).expire(k, windowS, 'NX').exec()) ?? [];
  const hits = Number(res[0]?.[1] ?? 0);
  if (hits > limit) {
    const ttl = await redis.ttl(k);
    throw new HttpException(
      { message: 'Too many requests, please slow down', code: 'RATE_LIMITED', details: { retryInSeconds: ttl > 0 ? ttl : windowS } },
      HttpStatus.TOO_MANY_REQUESTS,
    );
  }
}

/** The caller's IP: the first X-Forwarded-For entry (Caddy / the admin page forward it), else the socket's. */
export function clientIp(req: { headers: Record<string, string | string[] | undefined>; ip?: string }): string {
  const xff = req.headers['x-forwarded-for'];
  const first = (Array.isArray(xff) ? xff[0] : xff)?.split(',')[0]?.trim();
  return first || req.ip || 'unknown';
}
