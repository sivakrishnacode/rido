import { Body, Controller, Delete, Get, Header, HttpCode, Param, ParseBoolPipe, Patch, Post, Put, Query, UseInterceptors } from '@nestjs/common';

import { Roles } from '../../core/auth/roles.decorator.js';
import type { Announcement, AuditLog, Payment } from '../../generated/prisma/client.js';
import { Role } from '../../generated/prisma/enums.js';
import type { Settings } from '../settings/settings.defaults.js';
import { SettingsService } from '../settings/settings.service.js';
import { AdminOpsService, LiveDriver } from './admin-ops.service.js';
import type { Paged } from './admin.types.js';
import { AuditInterceptor } from './audit.interceptor.js';
import { CreateAnnouncementDto } from './dto/announcement.dto.js';
import { ListQueryDto } from './dto/list-query.dto.js';

/** Live map, payments, announcements, settings, audit log and CSV export. */
@Roles(Role.ADMIN)
@UseInterceptors(AuditInterceptor)
@Controller('admin')
export class AdminOpsController {
  constructor(
    private readonly ops: AdminOpsService,
    private readonly settings: SettingsService,
  ) {}

  @Get('live')
  live(): Promise<{ drivers: LiveDriver[]; trips: unknown[] }> {
    return this.ops.live();
  }

  @Get('payments')
  payments(@Query() q: ListQueryDto): Promise<Paged<Payment>> {
    return this.ops.payments(q);
  }

  @Get('announcements')
  announcements(): Promise<Announcement[]> {
    return this.ops.announcements();
  }

  @Post('announcements')
  createAnnouncement(@Body() body: CreateAnnouncementDto): Promise<Announcement> {
    return this.ops.createAnnouncement(body);
  }

  @Patch('announcements/:id')
  toggleAnnouncement(@Param('id') id: string, @Body('isActive', ParseBoolPipe) isActive: boolean): Promise<Announcement> {
    return this.ops.setAnnouncementActive(id, isActive);
  }

  @Delete('announcements/:id')
  @HttpCode(204)
  removeAnnouncement(@Param('id') id: string): Promise<void> {
    return this.ops.removeAnnouncement(id);
  }

  @Get('settings')
  getSettings(): Promise<Settings> {
    return this.settings.all();
  }

  @Put('settings')
  putSettings(@Body() body: Record<string, unknown>): Promise<Settings> {
    return this.settings.update(body);
  }

  /** ?kind=<entity>&q=<action text> */
  @Get('audit')
  audit(@Query() q: ListQueryDto): Promise<Paged<AuditLog>> {
    return this.ops.audit(q);
  }

  @Get('export/trips.csv')
  @Header('Content-Type', 'text/csv; charset=utf-8')
  @Header('Content-Disposition', 'attachment; filename="rido-trips.csv"')
  exportTrips(): Promise<string> {
    return this.ops.exportCsv('trips');
  }

  @Get('export/drivers.csv')
  @Header('Content-Type', 'text/csv; charset=utf-8')
  @Header('Content-Disposition', 'attachment; filename="rido-drivers.csv"')
  exportDrivers(): Promise<string> {
    return this.ops.exportCsv('drivers');
  }

  @Get('export/payments.csv')
  @Header('Content-Type', 'text/csv; charset=utf-8')
  @Header('Content-Disposition', 'attachment; filename="rido-payments.csv"')
  exportPayments(): Promise<string> {
    return this.ops.exportCsv('payments');
  }
}
