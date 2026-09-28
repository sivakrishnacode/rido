import { Module } from '@nestjs/common';

import { AuditInterceptor } from '../admin/audit.interceptor.js';
import { DriversModule } from '../drivers/drivers.module.js';
import { AdminSafetyController } from './admin-safety.controller.js';
import { SafetyController } from './safety.controller.js';
import { ShareService } from './share.service.js';
import { SosService } from './sos.service.js';

/** Rider and driver safety: SOS (and the admin queue), live trip share links. */
@Module({
  imports: [DriversModule],
  controllers: [SafetyController, AdminSafetyController],
  providers: [ShareService, SosService, AuditInterceptor],
  exports: [ShareService, SosService],
})
export class SafetyModule {}
