import type { Env } from '../../core/config/env.js';
import type { RedisService } from '../../core/redis/redis.service.js';
import { OtpService } from './otp.service.js';

function fakeRedis(): RedisService {
  const store = new Map<string, string>();
  return {
    get: async (k: string) => store.get(k) ?? null,
    set: async (k: string, v: string) => (store.set(k, v), 'OK'),
    incr: async (k: string) => {
      const n = Number(store.get(k) ?? 0) + 1;
      store.set(k, String(n));
      return n;
    },
    expire: async () => 1,
    del: async (...keys: string[]) => keys.filter((k) => store.delete(k)).length,
  } as unknown as RedisService;
}

const otp = (env: Partial<Env>): OtpService => new OtpService(fakeRedis(), { isOtpDevMode: true, devOtpCode: '', ...env } as Env);

describe('OtpService', () => {
  it('dev mode without DEV_OTP_CODE: any 6 digits except 000000', async () => {
    const s = otp({});
    expect(await s.verify('+919000000001', '123456')).toBe(true);
    expect(await s.verify('+919000000001', '000000')).toBe(false);
  });

  it('dev mode with DEV_OTP_CODE: only that code signs in', async () => {
    const s = otp({ devOtpCode: '482915' });
    expect(await s.verify('+919000000001', '123456')).toBe(false);
    expect(await s.verify('+919000000001', '482915')).toBe(true);
  });

  it('live mode: only the code that was sent', async () => {
    const s = otp({ isOtpDevMode: false });
    expect(await s.verify('+919000000002', '123456')).toBe(false);
    await s.send('+919000000002');
    expect(await s.verify('+919000000002', '123456')).toBe(false);
  });
});
