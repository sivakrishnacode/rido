import { Injectable } from '@nestjs/common';

import { PrismaService } from '../../core/prisma/prisma.service.js';
import type { SupportTicket } from '../../generated/prisma/client.js';
import type { CreateTicketDto } from './dto/create-ticket.dto.js';

/** Help topics and support tickets for both apps. */
@Injectable()
export class SupportService {
  static readonly passengerTopics = ['Lost item', 'Driver behaviour', 'Fare issue', 'Parcel issue', 'App problem', 'Safety concern'] as const;
  static readonly driverTopics = ['Payment issue', 'Plan & Autopay', 'Documents / KYC', 'Rider behaviour', 'App problem', 'Safety concern'] as const;

  constructor(private readonly prisma: PrismaService) {}

  list(userId: string): Promise<SupportTicket[]> {
    return this.prisma.supportTicket.findMany({ where: { userId }, orderBy: { createdAt: 'desc' } });
  }

  create(userId: string, dto: CreateTicketDto): Promise<SupportTicket> {
    return this.prisma.supportTicket.create({ data: { ...dto, userId } });
  }
}
