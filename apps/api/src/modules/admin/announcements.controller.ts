import { Controller, Get, Query } from '@nestjs/common';

import { Public } from '../../core/auth/public.decorator.js';
import { PrismaService } from '../../core/prisma/prisma.service.js';
import type { Announcement } from '../../generated/prisma/client.js';
import { AnnouncementAudience } from '../../generated/prisma/enums.js';

/** Active announcements for the apps: GET /announcements?audience=PASSENGER|DRIVER&cityId=coimbatore */
@Public()
@Controller('announcements')
export class AnnouncementsController {
  constructor(private readonly prisma: PrismaService) {}

  @Get()
  list(@Query('audience') audience?: string, @Query('cityId') cityId?: string): Promise<Announcement[]> {
    const aud = Object.values(AnnouncementAudience).includes(audience as AnnouncementAudience) ? (audience as AnnouncementAudience) : undefined;
    const now = new Date();
    return this.prisma.announcement.findMany({
      where: {
        isActive: true,
        startsAt: { lte: now },
        OR: [{ endsAt: null }, { endsAt: { gt: now } }],
        audience: aud ? { in: [AnnouncementAudience.ALL, aud] } : undefined,
        AND: cityId ? [{ OR: [{ cityId: null }, { cityId }] }] : undefined,
      },
      orderBy: { createdAt: 'desc' },
      take: 20,
    });
  }
}
