import { Module } from '@nestjs/common';

import { AdminApprovalsService } from './admin-approvals.service.js';
import { AdminCitiesController } from './admin-cities.controller.js';
import { AdminCitiesService } from './admin-cities.service.js';
import { AdminHeatmapService } from './admin-heatmap.service.js';
import { AdminOpsController } from './admin-ops.controller.js';
import { AdminOpsService } from './admin-ops.service.js';
import { AdminStatsService } from './admin-stats.service.js';
import { AdminUsersController } from './admin-users.controller.js';
import { AdminUsersService } from './admin-users.service.js';
import { AdminController } from './admin.controller.js';
import { AdminService } from './admin.service.js';
import { AnnouncementsController } from './announcements.controller.js';
import { AuditInterceptor } from './audit.interceptor.js';
import { KycModule } from '../kyc/kyc.module.js';
import { TripsModule } from '../trips/trips.module.js';

/** Admin panel API (ADMIN role only) and public announcements. */
@Module({
  imports: [KycModule, TripsModule],
  controllers: [AdminController, AdminCitiesController, AdminUsersController, AdminOpsController, AnnouncementsController],
  providers: [AdminService, AdminApprovalsService, AdminStatsService, AdminCitiesService, AdminUsersService, AdminOpsService, AdminHeatmapService, AuditInterceptor],
})
export class AdminModule {}
