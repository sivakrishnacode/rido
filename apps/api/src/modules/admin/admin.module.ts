import { Module } from '@nestjs/common';

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

/** Admin panel API (ADMIN role only) and public announcements. */
@Module({
  controllers: [AdminController, AdminCitiesController, AdminUsersController, AdminOpsController, AnnouncementsController],
  providers: [AdminService, AdminStatsService, AdminCitiesService, AdminUsersService, AdminOpsService, AdminHeatmapService, AuditInterceptor],
})
export class AdminModule {}
