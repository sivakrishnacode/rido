import { HttpException, HttpStatus, Inject, Injectable, Logger } from '@nestjs/common';
import { randomInt } from 'node:crypto';

import type { Env } from '../../core/config/env.js';
import { ENV } from '../../core/config/env.token.js';
import { RedisService } from '../../core/redis/redis.service.js';

const OTP_TTL_S = 300;
const MAX_SENDS = 5;
const SEND_WINDOW_S = 900;
const MAX_ATTEMPTS = 5;

/** One-time codes in Redis with send and attempt limits. Swap `deliver` for an SMS provider (MSG91, Twilio…). */
@Injectable()
export class OtpService {
  private readonly logger = new Logger(OtpService.name);

  constructor(
    private readonly redis: RedisService,
    @Inject(ENV) private readonly env: Env,
  ) {}

  async send(phone: string): Promise<{ expiresInSeconds: number }> {
    const sends = await this.redis.incr(`otp:sends:${phone}`);
    if (sends === 1) await this.redis.expire(`otp:sends:${phone}`, SEND_WINDOW_S);
    if (sends > MAX_SENDS) throw new HttpException('Too many OTP requests. Try again later.', HttpStatus.TOO_MANY_REQUESTS);
    const code = String(randomInt(0, 1_000_000)).padStart(6, '0');
    await this.redis.set(`otp:code:${phone}`, code, 'EX', OTP_TTL_S);
    await this.redis.del(`otp:attempts:${phone}`);
    this.deliver(phone, code);
    return { expiresInSeconds: OTP_TTL_S };
  }

  /** True if [code] is right. In dev mode any 6 digits except 000000 pass (like the prototype). */
  async verify(phone: string, code: string): Promise<boolean> {
    const attempts = await this.redis.incr(`otp:attempts:${phone}`);
    if (attempts === 1) await this.redis.expire(`otp:attempts:${phone}`, OTP_TTL_S);
    if (attempts > MAX_ATTEMPTS) throw new HttpException('Too many wrong attempts. Request a new OTP.', HttpStatus.TOO_MANY_REQUESTS);
    const expected = await this.redis.get(`otp:code:${phone}`);
    const isValid = this.env.isOtpDevMode ? code !== '000000' : expected !== null && expected === code;
    if (isValid) await this.redis.del(`otp:code:${phone}`, `otp:attempts:${phone}`);
    return isValid;
  }

  private deliver(phone: string, code: string): void {
    if (this.env.isOtpDevMode) this.logger.log(`OTP for ${phone}: ${code}`);
    // Production: send via SMS provider here.
  }
}
