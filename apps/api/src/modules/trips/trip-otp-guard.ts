import { BadRequestException, HttpException, HttpStatus, Injectable } from '@nestjs/common';

import { RedisService } from '../../core/redis/redis.service.js';

/** Tries allowed per window for one trip's 4-digit OTP (ride start or parcel delivery). */
export const OTP_MAX_TRIES = 5;
/** The window starts at the first try; after [OTP_MAX_TRIES] the OTP is locked until it ends. */
export const OTP_WINDOW_S = 60;

/**
 * Limits guesses of a trip's 4-digit OTP (it would otherwise fall to 10,000 tries). Every try counts, counted before
 * the compare so parallel requests can't slip past; the right OTP clears the count. The 5th wrong try and any try
 * while locked → 429 `OTP_LOCKED` with `details.retryInSeconds`.
 */
@Injectable()
export class TripOtpGuard {
  constructor(private readonly redis: RedisService) {}

  async check(params: { tripId: string; expected: string; given: string | undefined; who: 'rider' | 'receiver' }): Promise<void> {
    const key = `trip:otp-tries:${params.tripId}`;
    const [[, tries]] = ((await this.redis.multi().incr(key).expire(key, OTP_WINDOW_S, 'NX').exec()) ?? [[null, 1]]) as [[unknown, number]];
    if (tries > OTP_MAX_TRIES) throw this.locked(params.who, await this.redis.ttl(key));
    if (params.given === params.expected) {
      await this.redis.del(key);
      return;
    }
    if (tries === OTP_MAX_TRIES) throw this.locked(params.who, await this.redis.ttl(key));
    throw new BadRequestException({ message: 'Wrong OTP, please try again', code: 'WRONG_OTP', details: { triesLeft: OTP_MAX_TRIES - tries } });
  }

  private locked(who: 'rider' | 'receiver', ttl: number): HttpException {
    return new HttpException(
      {
        message: `Too many wrong OTPs. Ask the ${who} to read it again in a minute`,
        code: 'OTP_LOCKED',
        details: { retryInSeconds: ttl > 0 ? ttl : OTP_WINDOW_S },
      },
      HttpStatus.TOO_MANY_REQUESTS,
    );
  }
}
