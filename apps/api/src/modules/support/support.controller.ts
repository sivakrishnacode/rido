import { Body, Controller, Get, HttpCode, Param, Post, Query, UploadedFile, UseInterceptors } from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';

import type { AuthUser } from '../../core/auth/auth-user.js';
import { CurrentUser } from '../../core/auth/current-user.decorator.js';
import { Public } from '../../core/auth/public.decorator.js';
import { MAX_UPLOAD_BYTES, type UploadedBlob } from '../../core/storage/file-storage.service.js';
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

  /** `tripId`, when given, must be one of the user's trips (as passenger or its driver), else 400. */
  @Post('tickets')
  create(@CurrentUser() user: AuthUser, @Body() body: CreateTicketDto): Promise<SupportTicket> {
    return this.support.create(user.userId, body);
  }

  /** One photo on the user's own ticket: multipart `file` (JPG / PNG / WebP ≤ 8 MB) → the ticket with `attachmentFile`. */
  @Post('tickets/:id/attachment')
  @HttpCode(200)
  @UseInterceptors(FileInterceptor('file', { limits: { fileSize: MAX_UPLOAD_BYTES } }))
  attach(@CurrentUser() user: AuthUser, @Param('id') id: string, @UploadedFile() file?: UploadedBlob): Promise<SupportTicket> {
    return this.support.attach(user.userId, id, file);
  }
}
