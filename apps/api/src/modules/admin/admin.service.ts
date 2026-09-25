import { Injectable } from '@nestjs/common';

import { PrismaService } from '../../core/prisma/prisma.service.js';
import type { Driver, KycDocument, Plan, Prisma, SupportTicket, Trip, User } from '../../generated/prisma/client.js';
import { DriverStatus, KycDocType, KycStatus, Role, TicketStatus } from '../../generated/prisma/enums.js';
import type { Paged } from './admin.types.js';
import type { ListQueryDto } from './dto/list-query.dto.js';

function paging(q: ListQueryDto): { skip: number; take: number; page: number; pageSize: number } {
  const page = q.page ?? 1;
  const pageSize = q.pageSize ?? 20;
  return { skip: (page - 1) * pageSize, take: pageSize, page, pageSize };
}

function isOneOf<T extends string>(value: string | undefined, values: readonly T[]): value is T {
  return !!value && (values as readonly string[]).includes(value);
}

/** Admin lists and actions: drivers + KYC, trips, passengers, plans, tickets. */
@Injectable()
export class AdminService {
  constructor(private readonly prisma: PrismaService) {}

  async drivers(q: ListQueryDto): Promise<Paged<Driver>> {
    const { skip, take, page, pageSize } = paging(q);
    const where: Prisma.DriverWhereInput = {
      status: isOneOf(q.status, Object.values(DriverStatus)) ? q.status : undefined,
      OR: q.q
        ? [{ plate: { contains: q.q, mode: 'insensitive' } }, { user: { name: { contains: q.q, mode: 'insensitive' } } }, { user: { phone: { contains: q.q } } }]
        : undefined,
    };
    const [items, total] = await Promise.all([
      this.prisma.driver.findMany({
        where, skip, take, orderBy: { createdAt: 'desc' },
        include: { user: true, documents: true, subscriptions: { orderBy: { endsAt: 'desc' }, take: 1, include: { plan: true } } },
      }),
      this.prisma.driver.count({ where }),
    ]);
    return { items, total, page, pageSize };
  }

  driver(id: string): Promise<Driver> {
    return this.prisma.driver.findUniqueOrThrow({
      where: { id },
      include: {
        user: true,
        documents: { orderBy: { type: 'asc' } },
        subscriptions: { orderBy: { endsAt: 'desc' }, include: { plan: true, payments: true } },
        trips: { orderBy: { createdAt: 'desc' }, take: 20 },
      },
    });
  }

  setDriverStatus(id: string, status: DriverStatus): Promise<Driver> {
    return this.prisma.driver.update({ where: { id }, data: { status, isOnline: status === DriverStatus.APPROVED ? undefined : false } });
  }

  /** Verify or reject one KYC document; all 5 verified → driver APPROVED, any rejected → REJECTED. */
  async reviewDocument(params: { driverId: string; type: KycDocType; status: 'VERIFIED' | 'REJECTED'; reason?: string }): Promise<KycDocument[]> {
    await this.prisma.kycDocument.update({
      where: { driverId_type: { driverId: params.driverId, type: params.type } },
      data: { status: params.status, rejectReason: params.status === 'REJECTED' ? (params.reason ?? 'Please upload a clearer image') : null },
    });
    const docs = await this.prisma.kycDocument.findMany({ where: { driverId: params.driverId }, orderBy: { type: 'asc' } });
    const isAllVerified = docs.every((d) => d.status === KycStatus.VERIFIED);
    const hasRejected = docs.some((d) => d.status === KycStatus.REJECTED);
    if (isAllVerified || hasRejected) {
      await this.prisma.driver.update({ where: { id: params.driverId }, data: { status: isAllVerified ? DriverStatus.APPROVED : DriverStatus.REJECTED } });
    }
    return docs;
  }

  async trips(q: ListQueryDto): Promise<Paged<Trip>> {
    const { skip, take, page, pageSize } = paging(q);
    const where: Prisma.TripWhereInput = {
      status: q.status ? (q.status as Trip['status']) : undefined,
      kind: q.kind === 'RIDE' || q.kind === 'PARCEL' ? q.kind : undefined,
      OR: q.q ? [{ id: { contains: q.q } }, { pickupName: { contains: q.q, mode: 'insensitive' } }, { dropName: { contains: q.q, mode: 'insensitive' } }] : undefined,
    };
    const [items, total] = await Promise.all([
      this.prisma.trip.findMany({ where, skip, take, orderBy: { createdAt: 'desc' }, include: { passenger: true, driver: { include: { user: true } } } }),
      this.prisma.trip.count({ where }),
    ]);
    return { items, total, page, pageSize };
  }

  trip(id: string): Promise<Trip> {
    return this.prisma.trip.findUniqueOrThrow({ where: { id }, include: { passenger: true, driver: { include: { user: true } }, tickets: true } });
  }

  async passengers(q: ListQueryDto): Promise<Paged<User>> {
    const { skip, take, page, pageSize } = paging(q);
    const where: Prisma.UserWhereInput = {
      role: Role.PASSENGER,
      OR: q.q ? [{ name: { contains: q.q, mode: 'insensitive' } }, { phone: { contains: q.q } }] : undefined,
    };
    const [items, total] = await Promise.all([
      this.prisma.user.findMany({ where, skip, take, orderBy: { createdAt: 'desc' }, include: { _count: { select: { trips: true } } } }),
      this.prisma.user.count({ where }),
    ]);
    return { items, total, page, pageSize };
  }

  plans(): Promise<Plan[]> {
    return this.prisma.plan.findMany({ orderBy: [{ vehicleKind: 'asc' }, { price: 'asc' }] });
  }

  updatePlan(id: string, data: { price?: number; isActive?: boolean }): Promise<Plan> {
    return this.prisma.plan.update({ where: { id }, data });
  }

  async tickets(q: ListQueryDto): Promise<Paged<SupportTicket>> {
    const { skip, take, page, pageSize } = paging(q);
    const where: Prisma.SupportTicketWhereInput = { status: isOneOf(q.status, Object.values(TicketStatus)) ? q.status : undefined };
    const [items, total] = await Promise.all([
      this.prisma.supportTicket.findMany({ where, skip, take, orderBy: { createdAt: 'desc' }, include: { user: true, trip: true } }),
      this.prisma.supportTicket.count({ where }),
    ]);
    return { items, total, page, pageSize };
  }

  setTicketStatus(id: string, status: TicketStatus): Promise<SupportTicket> {
    return this.prisma.supportTicket.update({ where: { id }, data: { status } });
  }
}
