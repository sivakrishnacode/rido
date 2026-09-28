import { Global, Module } from '@nestjs/common';

import { JobsService } from './jobs.service.js';

/** Makes [JobsService] (durable Redis-backed timers) available everywhere. */
@Global()
@Module({ providers: [JobsService], exports: [JobsService] })
export class JobsModule {}
