import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';

import { PrismaService } from '../../core/prisma/prisma.service.js';
import { FileStorageService, type UploadedBlob } from '../../core/storage/file-storage.service.js';
import type { SupportTicket } from '../../generated/prisma/client.js';
import type { CreateTicketDto } from './dto/create-ticket.dto.js';

const IMAGE_TYPES = ['image/jpeg', 'image/png', 'image/webp'];

/** Help topics and support tickets for both apps. */
@Injectable()
export class SupportService {
  static readonly passengerTopics = ['Lost item', 'Driver behaviour', 'Fare issue', 'Parcel issue', 'App problem', 'Safety concern'] as const;
  static readonly driverTopics = ['Payment issue', 'Plan & Autopay', 'Documents / KYC', 'Rider behaviour', 'App problem', 'Safety concern', 'Delete my account'] as const;

  constructor(
    private readonly prisma: PrismaService,
    private readonly files: FileStorageService,
  ) {}

  list(userId: string): Promise<SupportTicket[]> {
    return this.prisma.supportTicket.findMany({ where: { userId }, orderBy: { createdAt: 'desc' } });
  }

  /** A trip named on the ticket must be the user's own: booked by them, or driven by them. Else 400. */
  async create(userId: string, dto: CreateTicketDto): Promise<SupportTicket> {
    if (dto.tripId) {
      const trip = await this.prisma.trip.findUnique({ where: { id: dto.tripId }, select: { passengerId: true, driver: { select: { userId: true } } } });
      if (!trip || (trip.passengerId !== userId && trip.driver?.userId !== userId)) throw new BadRequestException('Choose one of your own trips');
    }
    return this.prisma.supportTicket.create({ data: { ...dto, userId } });
  }

  /** One photo on the user's own ticket (JPG / PNG / WebP ≤ 8 MB); a new one replaces it. Others' tickets → 404. */
  async attach(userId: string, ticketId: string, file?: UploadedBlob): Promise<SupportTicket> {
    const ticket = await this.prisma.supportTicket.findUnique({ where: { id: ticketId }, select: { userId: true } });
    if (!ticket || ticket.userId !== userId) throw new NotFoundException('Ticket not found');
    if (!file?.buffer?.length || !IMAGE_TYPES.includes(file.mimetype)) throw new BadRequestException('Attach a photo (JPG, PNG or WebP)');
    const attachmentFile = await this.files.save(file);
    return this.prisma.supportTicket.update({ where: { id: ticketId }, data: { attachmentFile } });
  }
}
