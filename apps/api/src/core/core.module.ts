import { Global, Module, ValidationPipe } from '@nestjs/common';
import { APP_FILTER, APP_GUARD, APP_PIPE } from '@nestjs/core';
import { JwtModule } from '@nestjs/jwt';

import { JwtAuthGuard } from './auth/jwt-auth.guard.js';
import { RolesGuard } from './auth/roles.guard.js';
import { loadEnv } from './config/env.js';
import { EnvModule } from './config/env.module.js';
import { AllExceptionsFilter } from './filters/all-exceptions.filter.js';
import { PrismaModule } from './prisma/prisma.module.js';
import { RedisModule } from './redis/redis.module.js';

const env = loadEnv();

/** Cross-cutting setup: config, database, Redis, JWT, global guards, validation and error filter. */
@Global()
@Module({
  imports: [
    EnvModule,
    PrismaModule,
    RedisModule,
    JwtModule.register({ global: true, secret: env.jwtSecret, signOptions: { expiresIn: env.jwtExpiresIn as never } }),
  ],
  providers: [
    { provide: APP_GUARD, useClass: JwtAuthGuard },
    { provide: APP_GUARD, useClass: RolesGuard },
    { provide: APP_FILTER, useClass: AllExceptionsFilter },
    { provide: APP_PIPE, useValue: new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true }) },
  ],
  exports: [EnvModule],
})
export class CoreModule {}
