import { Body, Controller, Get, Post, Query } from '@nestjs/common';

import type { AuthUser } from '../../core/auth/auth-user.js';
import { CurrentUser } from '../../core/auth/current-user.decorator.js';
import { Public } from '../../core/auth/public.decorator.js';
import type { SupportTicket } from '../../generated/prisma/client.js';
import { CreateTicketDto } from './dto/create-ticket.dto.js';
import { SupportService } from './support.service.js';

/** P-25 / P-25b and the driver help screens. */
@Controller()
export class SupportController {
  constructor(private readonly support: SupportService) {}

  @Public()
  @Get('support/topics')
  topics(@Query('app') app?: string): readonly string[] {
    return app === 'driver' ? SupportService.driverTopics : SupportService.passengerTopics;
  }

  @Get('tickets')
  list(@CurrentUser() user: AuthUser): Promise<SupportTicket[]> {
    return this.support.list(user.userId);
  }

  @Post('tickets')
  create(@CurrentUser() user: AuthUser, @Body() body: CreateTicketDto): Promise<SupportTicket> {
    return this.support.create(user.userId, body);
  }
}
