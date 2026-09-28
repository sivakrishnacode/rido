import { Module } from '@nestjs/common';

import { DriversModule } from '../drivers/drivers.module.js';
import { SafetyController } from './safety.controller.js';
import { ShareService } from './share.service.js';

/** Rider and driver safety: live trip share links. */
@Module({
  imports: [DriversModule],
  controllers: [SafetyController],
  providers: [ShareService],
  exports: [ShareService],
})
export class SafetyModule {}
