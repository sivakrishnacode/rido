import { Global, Module } from '@nestjs/common';

import { RedisService } from './redis.service.js';

/** Makes [RedisService] available everywhere. */
@Global()
@Module({ providers: [RedisService], exports: [RedisService] })
export class RedisModule {}
