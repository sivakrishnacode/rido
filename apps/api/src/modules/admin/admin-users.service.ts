import { Injectable } from '@nestjs/common';

import { PrismaService } from '../../core/prisma/prisma.service.js';
import { RedisService } from '../../core/redis/redis.service.js';
import type { KycDocument, Prisma, User } from '../../generated/prisma/client.js';
import { KycStatus, Role } from '../../generated/prisma/enums.js';
import type { Paged } from './admin.types.js';
import type { ListQueryDto } from './dto/list-query.dto.js';
import type { UpdateUserDto } from './dto/update-user.dto.js';

/** All accounts (passengers, drivers, admins): search, roles, block/unblock; plus the KYC review queue. */
@Injectable()
export class AdminUsersService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly redis: RedisService,
  ) {}

  async users(q: ListQueryDto & { role?: string; blocked?: string }): Promise<Paged<User>> {
    const page = q.page ?? 1;
    const pageSize = q.pageSize ?? 20;
    const role = Object.values(Role).includes(q.role as Role) ? (q.role as Role) : undefined;
    const where: Prisma.UserWhereInput = {
      role,
      isBlocked: q.blocked === 'true' ? true : q.blocked === 'false' ? false : undefined,
      OR: q.q ? [{ name: { contains: q.q, mode: 'insensitive' } }, { phone: { contains: q.q } }, { email: { contains: q.q, mode: 'insensitive' } }] : undefined,
    };
    const [items, total] = await Promise.all([
      this.prisma.user.findMany({
        where, skip: (page - 1) * pageSize, take: pageSize, orderBy: { createdAt: 'desc' },
        include: { driver: { select: { id: true, status: true, vehicleKind: true, plate: true } }, _count: { select: { trips: true, tickets: true } } },
      }),
      this.prisma.user.count({ where }),
    ]);
    return { items, total, page, pageSize };
  }

  user(id: string): Promise<User> {
    return this.prisma.user.findUniqueOrThrow({
      where: { id },
      include: {
        driver: { include: { documents: true } },
        emergencyContacts: true,
        savedPlaces: true,
        trips: { orderBy: { createdAt: 'desc' }, take: 20 },
        tickets: { orderBy: { createdAt: 'desc' }, take: 20 },
      },
    });
  }

  /** Updates a user; blocking also takes effect immediately for existing tokens (Redis flag). */
  async update(id: string, dto: UpdateUserDto): Promise<User> {
    const user = await this.prisma.user.update({
      where: { id },
      data: { ...dto, blockedReason: dto.isBlocked === false ? null : dto.blockedReason },
    });
    if (user.isBlocked) await this.redis.set(`user:blocked:${id}`, '1');
    else await this.redis.del(`user:blocked:${id}`);
    return user;
  }

  /** KYC documents waiting for review (or in another status), oldest first. */
  async kycQueue(q: ListQueryDto): Promise<Paged<KycDocument>> {
    const page = q.page ?? 1;
    const pageSize = q.pageSize ?? 20;
    const status = Object.values(KycStatus).includes(q.status as KycStatus) ? (q.status as KycStatus) : KycStatus.UNDER_REVIEW;
    const where: Prisma.KycDocumentWhereInput = { status };
    const [items, total] = await Promise.all([
      this.prisma.kycDocument.findMany({
        where, skip: (page - 1) * pageSize, take: pageSize, orderBy: { updatedAt: 'asc' },
        include: { driver: { include: { user: { select: { id: true, name: true, phone: true } } } } },
      }),
      this.prisma.kycDocument.count({ where }),
    ]);
    return { items, total, page, pageSize };
  }
}
