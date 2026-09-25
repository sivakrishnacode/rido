import { Inject, Injectable, OnModuleDestroy } from '@nestjs/common';
import { Redis } from 'ioredis';

import type { Env } from '../config/env.js';
import { ENV } from '../config/env.token.js';

/**
 * Shared Redis connection. Used for OTPs and rate limits, live driver locations (GEO sets),
 * dispatch offers and busy flags.
 */
@Injectable()
export class RedisService extends Redis implements OnModuleDestroy {
  constructor(@Inject(ENV) env: Env) {
    super(env.redisUrl, { maxRetriesPerRequest: 3, lazyConnect: false });
  }

  async onModuleDestroy(): Promise<void> {
    await this.quit();
  }
}
