import { HttpException, HttpStatus } from '@nestjs/common';

import type { RedisService } from '../redis/redis.service.js';

/** What every rate-limited endpoint answers (with HTTP 429 and a Retry-After header). */
export const RATE_LIMIT_MESSAGE = 'Too many requests. Please wait a moment and try again.';

/**
 * HTTP 429 `{ statusCode: 429, message, code, details: { retryInSeconds } }`. The error filter also sends
 * `Retry-After: <retryInSeconds>`. [message] / [code] default to the generic limit ([RATE_LIMIT_MESSAGE],
 * `RATE_LIMITED`); OTP limits use their own words.
 */
export class TooManyRequestsException extends HttpException {
  constructor(
    readonly retryAfterS: number,
    opts: { message?: string; code?: string } = {},
  ) {
    const retryInSeconds = Math.max(1, Math.ceil(retryAfterS));
    super(
      { message: opts.message ?? RATE_LIMIT_MESSAGE, code: opts.code ?? 'RATE_LIMITED', details: { retryInSeconds } },
      HttpStatus.TOO_MANY_REQUESTS,
    );
    this.name = 'TooManyRequests';
  }
}

/**
 * One hit on the fixed-window counter `rl:<key>` ([windowS] seconds from the first hit): the hits so far in this
 * window and the seconds until it resets. One INCR + EXPIRE NX (+ TTL) round trip.
 */
export async function countHit(redis: RedisService, key: string, windowS: number): Promise<{ hits: number; resetInS: number }> {
  const k = `rl:${key}`;
  const res = (await redis.multi().incr(k).expire(k, windowS, 'NX').ttl(k).exec()) ?? [];
  const ttl = Number(res[2]?.[1] ?? -1);
  return { hits: Number(res[0]?.[1] ?? 0), resetInS: ttl > 0 ? ttl : windowS };
}

/** Throws [TooManyRequestsException] once [key] was hit more than [limit] times in the current [windowS] window. */
export async function rateLimit(redis: RedisService, key: string, limit: number, windowS: number): Promise<void> {
  const { hits, resetInS } = await countHit(redis, key, windowS);
  if (hits > limit) throw new TooManyRequestsException(resetInS);
}
