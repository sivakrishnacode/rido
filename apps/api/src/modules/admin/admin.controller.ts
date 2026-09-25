import { Body, Controller, Get, Param, ParseEnumPipe, Patch, Post, Query, UseInterceptors } from '@nestjs/common';

import { Roles } from '../../core/auth/roles.decorator.js';
import type { Driver, KycDocument, Plan, SupportTicket, Trip, User } from '../../generated/prisma/client.js';
import { KycDocType, Role } from '../../generated/prisma/enums.js';
import { AdminStatsService } from './admin-stats.service.js';
import { AdminService } from './admin.service.js';
import type { AdminStats, Paged } from './admin.types.js';
import { AuditInterceptor } from './audit.interceptor.js';
import { DocumentReviewDto } from './dto/document-review.dto.js';
import { DriverStatusDto } from './dto/driver-status.dto.js';
import { ListQueryDto } from './dto/list-query.dto.js';
import { TicketStatusDto } from './dto/ticket-status.dto.js';
import { UpdatePlanDto } from './dto/update-plan.dto.js';

/** Admin panel API. Sign in with a phone listed in ADMIN_PHONES. */
@Roles(Role.ADMIN)
@UseInterceptors(AuditInterceptor)
@Controller('admin')
export class AdminController {
  constructor(
    private readonly admin: AdminService,
    private readonly statsService: AdminStatsService,
  ) {}

  @Get('stats')
  stats(): Promise<AdminStats> {
    return this.statsService.stats();
  }

  @Get('drivers')
  drivers(@Query() q: ListQueryDto): Promise<Paged<Driver>> {
    return this.admin.drivers(q);
  }

  @Get('drivers/:id')
  driver(@Param('id') id: string): Promise<Driver> {
    return this.admin.driver(id);
  }

  @Patch('drivers/:id')
  setDriverStatus(@Param('id') id: string, @Body() body: DriverStatusDto): Promise<Driver> {
    return this.admin.setDriverStatus(id, body.status);
  }

  @Post('drivers/:id/documents/:type')
  reviewDocument(
    @Param('id') id: string,
    @Param('type', new ParseEnumPipe(KycDocType)) type: KycDocType,
    @Body() body: DocumentReviewDto,
  ): Promise<KycDocument[]> {
    return this.admin.reviewDocument({ driverId: id, type, ...body });
  }

  @Get('trips')
  trips(@Query() q: ListQueryDto): Promise<Paged<Trip>> {
    return this.admin.trips(q);
  }

  @Get('trips/:id')
  trip(@Param('id') id: string): Promise<Trip> {
    return this.admin.trip(id);
  }

  @Get('passengers')
  passengers(@Query() q: ListQueryDto): Promise<Paged<User>> {
    return this.admin.passengers(q);
  }

  @Get('plans')
  plans(): Promise<Plan[]> {
    return this.admin.plans();
  }

  @Patch('plans/:id')
  updatePlan(@Param('id') id: string, @Body() body: UpdatePlanDto): Promise<Plan> {
    return this.admin.updatePlan(id, body);
  }

  @Get('tickets')
  tickets(@Query() q: ListQueryDto): Promise<Paged<SupportTicket>> {
    return this.admin.tickets(q);
  }

  @Patch('tickets/:id')
  setTicketStatus(@Param('id') id: string, @Body() body: TicketStatusDto): Promise<SupportTicket> {
    return this.admin.setTicketStatus(id, body.status);
  }
}
