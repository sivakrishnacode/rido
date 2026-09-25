import { Module } from '@nestjs/common';

import { HealthController } from './health.controller.js';

/** Health endpoints. */
@Module({ controllers: [HealthController] })
export class HealthModule {}
