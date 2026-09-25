import { Global, Module } from '@nestjs/common';

import { loadEnv } from './env.js';
import { ENV } from './env.token.js';

/** Provides the validated [Env] app-wide. */
@Global()
@Module({ providers: [{ provide: ENV, useFactory: loadEnv }], exports: [ENV] })
export class EnvModule {}
