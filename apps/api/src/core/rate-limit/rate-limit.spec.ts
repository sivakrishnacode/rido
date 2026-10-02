import type { RedisService } from '../redis/redis.service.js';
import { clientIp, isFromSelf, isPrivateAddress } from './client-ip.js';
import { RATE_LIMIT_MESSAGE, rateLimit, TooManyRequestsException } from './rate-limit.js';
import { limitSubject } from './rate-limit.guard.js';

/** INCR / EXPIRE NX / TTL in memory, enough for [rateLimit]. */
function fakeRedis(): RedisService {
  const hits = new Map<string, number>();
  const ttls = new Map<string, number>();
  return {
    multi: () => {
      const ops: (() => [null, number])[] = [];
      const chain = {
        incr: (k: string) => (ops.push(() => [null, hits.set(k, (hits.get(k) ?? 0) + 1).get(k)!]), chain),
        expire: (k: string, s: number) => (ops.push(() => [null, ttls.has(k) ? 0 : (ttls.set(k, s), 1)]), chain),
        ttl: (k: string) => (ops.push(() => [null, ttls.get(k) ?? -1]), chain),
        exec: async () => ops.map((op) => op()),
      };
      return chain;
    },
  } as unknown as RedisService;
}

const req = (peer: string, xff?: string) => ({ headers: xff === undefined ? {} : { 'x-forwarded-for': xff }, socket: { remoteAddress: peer } });

describe('clientIp', () => {
  it('trusts X-Forwarded-For only from a loopback or private peer (Caddy in Docker, the admin server)', () => {
    expect(clientIp(req('172.18.0.4', '49.37.1.2'))).toBe('49.37.1.2');
    expect(clientIp(req('::ffff:127.0.0.1', '49.37.1.2'))).toBe('49.37.1.2');
    // Straight to port 3000 from the internet: the header is whatever the caller wants, so it is ignored.
    expect(clientIp(req('49.37.1.2', '1.1.1.1'))).toBe('49.37.1.2');
    expect(clientIp(req('::ffff:49.37.1.2'))).toBe('49.37.1.2');
  });

  it('reads the chain from the right, skipping our own private hops; all private → the first', () => {
    expect(clientIp(req('172.18.0.4', '8.8.8.8, 49.37.1.2, 172.18.0.3'))).toBe('49.37.1.2');
    expect(clientIp(req('127.0.0.1', '10.9.8.7'))).toBe('10.9.8.7');
    expect(clientIp(req('172.18.0.4', 'not-an-ip'))).toBe('172.18.0.4');
    expect(clientIp({ headers: {} })).toBe('unknown');
  });

  it('knows private and loopback addresses', () => {
    for (const a of ['10.1.2.3', '172.16.0.1', '172.31.255.255', '192.168.1.5', '127.0.0.1', '169.254.1.1', '::1', 'fd12:3456::1', 'fe80::1', '::ffff:10.0.0.1']) {
      expect(isPrivateAddress(a)).toBe(true);
    }
    for (const a of ['172.32.0.1', '49.37.1.2', '2401:4900::1', '100.64.0.1', '']) expect(isPrivateAddress(a)).toBe(false);
  });

  it('a request from this machine with no forwarded client is "self"', () => {
    expect(isFromSelf(req('::ffff:127.0.0.1'))).toBe(true);
    expect(isFromSelf(req('127.0.0.1', '49.37.1.2'))).toBe(false);
    expect(isFromSelf(req('172.18.0.4'))).toBe(false);
  });
});

describe('limitSubject', () => {
  it('limits signed-in callers per user, others per IP; admins and the machine itself are not limited', () => {
    expect(limitSubject({ ...req('49.37.1.2'), user: { userId: 'u1', role: 'PASSENGER' } })).toBe('u:u1');
    expect(limitSubject({ ...req('49.37.1.2'), user: { userId: 'a1', role: 'ADMIN' } })).toBeNull();
    expect(limitSubject(req('172.18.0.4', '49.37.1.2'))).toBe('ip:49.37.1.2');
    expect(limitSubject(req('127.0.0.1'))).toBeNull();
  });
});

describe('rateLimit', () => {
  it('lets [limit] calls through per window, then 429 with the standard message and the seconds left', async () => {
    const redis = fakeRedis();
    for (let i = 0; i < 3; i++) await rateLimit(redis, 'places-ac:u:u1', 3, 60);
    const err = await rateLimit(redis, 'places-ac:u:u1', 3, 60).catch((e: unknown) => e);
    expect(err).toBeInstanceOf(TooManyRequestsException);
    expect((err as TooManyRequestsException).getStatus()).toBe(429);
    expect((err as TooManyRequestsException).getResponse()).toEqual({ message: RATE_LIMIT_MESSAGE, code: 'RATE_LIMITED', details: { retryInSeconds: 60 } });
    // Another user has their own counter.
    await expect(rateLimit(redis, 'places-ac:u:u2', 3, 60)).resolves.toBeUndefined();
  });
});
