import { Injectable, OnApplicationBootstrap, OnModuleDestroy } from '@nestjs/common';

import { RedisService } from '../redis/redis.service.js';
import { JobRunner } from './job-runner.js';
import { RedisJobStore } from './redis-job-store.js';

const POLL_MS = 1_000;

/**
 * Durable timers for the whole API (offer expiry, re-search, trip timeouts): `schedule(kind, id, runAt, payload)`,
 * `cancel(kind, id)`. Stored in Redis, so an API restart doesn't lose them; every instance polls once a second and a
 * Lua claim makes sure each job runs on one of them. Handlers are registered by modules in `onModuleInit`; polling
 * starts once the app has booted.
 */
@Injectable()
export class JobsService extends JobRunner implements OnApplicationBootstrap, OnModuleDestroy {
  private poller: NodeJS.Timeout | null = null;
  private isPolling = false;

  constructor(redis: RedisService) {
    super(new RedisJobStore(redis));
  }

  onApplicationBootstrap(): void {
    this.poller = setInterval(() => void this.poll(), POLL_MS);
  }

  onModuleDestroy(): void {
    if (this.poller) clearInterval(this.poller);
    this.poller = null;
  }

  private async poll(): Promise<void> {
    if (this.isPolling) return;
    this.isPolling = true;
    try {
      await this.runDue();
    } catch (e) {
      this.logger.warn(`Job poll failed: ${(e as Error).message}`);
    } finally {
      this.isPolling = false;
    }
  }
}
