import { BadRequestException, HttpException, HttpStatus } from '@nestjs/common';

import type { RedisService } from '../../core/redis/redis.service.js';
import { OTP_MAX_TRIES, TripOtpGuard } from './trip-otp-guard.js';

/** Just the Redis calls the guard makes: INCR + EXPIRE NX in a MULTI, TTL, DEL. */
function fakeRedis(): RedisService {
  const counts = new Map<string, number>();
  const multi = () => {
    const ops: (() => [null, number])[] = [];
    const chain = {
      incr: (k: string) => (ops.push(() => [null, counts.set(k, (counts.get(k) ?? 0) + 1).get(k)!]), chain),
      expire: () => (ops.push(() => [null, 1]), chain),
      exec: async () => ops.map((op) => op()),
    };
    return chain;
  };
  return { multi, ttl: async () => 42, del: async (k: string) => Number(counts.delete(k)) } as unknown as RedisService;
}

const attempt = (guard: TripOtpGuard, given: string) => guard.check({ tripId: 't1', expected: '4829', given, who: 'rider' });

describe('TripOtpGuard', () => {
  it('passes the right OTP and says how many tries are left after a wrong one', async () => {
    const guard = new TripOtpGuard(fakeRedis());
    const wrong = await attempt(guard, '1111').catch((e: unknown) => e);
    expect(wrong).toBeInstanceOf(BadRequestException);
    expect((wrong as BadRequestException).getResponse()).toMatchObject({ code: 'WRONG_OTP', details: { triesLeft: OTP_MAX_TRIES - 1 } });
    await expect(attempt(guard, '4829')).resolves.toBeUndefined();
  });

  it('locks after five wrong tries, even for the right OTP', async () => {
    const guard = new TripOtpGuard(fakeRedis());
    for (let i = 1; i < OTP_MAX_TRIES; i++) await expect(attempt(guard, '0000')).rejects.toBeInstanceOf(BadRequestException);
    const fifth = (await attempt(guard, '0000').catch((e: unknown) => e)) as HttpException;
    expect(fifth.getStatus()).toBe(HttpStatus.TOO_MANY_REQUESTS);
    expect(fifth.getResponse()).toMatchObject({
      code: 'OTP_LOCKED',
      message: 'Too many wrong OTPs. Ask the rider to read it again in a minute',
      details: { retryInSeconds: 42 },
    });
    const locked = (await attempt(guard, '4829').catch((e: unknown) => e)) as HttpException;
    expect(locked.getStatus()).toBe(HttpStatus.TOO_MANY_REQUESTS);
  });

  it('a right OTP resets the count', async () => {
    const guard = new TripOtpGuard(fakeRedis());
    for (let i = 1; i < OTP_MAX_TRIES; i++) await attempt(guard, '0000').catch(() => undefined);
    await attempt(guard, '4829');
    await expect(attempt(guard, '0000')).rejects.toBeInstanceOf(BadRequestException);
  });
});
