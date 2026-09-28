import { Injectable } from '@nestjs/common';

import { DriverStateCache } from '../../core/driver-state/driver-state.cache.js';
import { PrismaService } from '../../core/prisma/prisma.service.js';
import type { Driver, KycDocument, Plan, Prisma, SupportTicket, Trip, User } from '../../generated/prisma/client.js';
import { DriverStatus, KycDocType, Role, TicketStatus } from '../../generated/prisma/enums.js';
import type { Paged } from './admin.types.js';
import type { ListQueryDto } from './dto/list-query.dto.js';
import { NotifierService } from '../notifications/notifier.service.js';
import { DriverApprovalService } from '../kyc/driver-approval.service.js';
import { REQUIRED_DOCS } from '../kyc/driver-approval.js';
import { type CancelRateStats, DriverBlocksService } from '../trips/driver-blocks.service.js';

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
  constructor(
    private readonly prisma: PrismaService,
    private readonly notifier: NotifierService,
    private readonly approval: DriverApprovalService,
    private readonly driverState: DriverStateCache,
    private readonly blocks: DriverBlocksService,
  ) {}

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
        include: { user: true, documents: { where: { type: { in: [...REQUIRED_DOCS] } } }, subscriptions: { orderBy: { endsAt: 'desc' }, take: 1, include: { plan: true } } },
      }),
      this.prisma.driver.count({ where }),
    ]);
    return { items, total, page, pageSize };
  }

  /** With the pause history and the cancellation rate now (7 days, trips/driver-blocks.service.ts). */
  async driver(id: string): Promise<Driver & { cancelRate: CancelRateStats }> {
    const driver = await this.prisma.driver.findUniqueOrThrow({
      where: { id },
      include: {
        blocks: { orderBy: { fromAt: 'desc' }, take: 20 },
        // Identity checks (Didit): newest first; the admin page shows the latest result and its reasons.
        user: { include: { identityChecks: { orderBy: { createdAt: 'desc' }, take: 5 } } },
        documents: { where: { type: { in: [...REQUIRED_DOCS] } }, orderBy: { type: 'asc' } },
        subscriptions: { orderBy: { endsAt: 'desc' }, include: { plan: true, payments: true } },
        trips: { orderBy: { createdAt: 'desc' }, take: 20 },
      },
    });
    return { ...driver, cancelRate: await this.blocks.stats(id) };
  }

  async setDriverStatus(id: string, status: DriverStatus): Promise<Driver> {
    const driver = await this.prisma.driver.update({ where: { id }, data: { status, isOnline: status === DriverStatus.APPROVED ? undefined : false } });
    await this.driverState.invalidate(id);
    return driver;
  }

  /** Verify or reject one document; RC + insurance verified and identity approved → APPROVED, any rejected → REJECTED. */
  async reviewDocument(params: { driverId: string; type: KycDocType; status: 'VERIFIED' | 'REJECTED'; reason?: string }): Promise<KycDocument[]> {
    await this.prisma.kycDocument.update({
      where: { driverId_type: { driverId: params.driverId, type: params.type } },
      data: { status: params.status, rejectReason: params.status === 'REJECTED' ? (params.reason ?? 'Please upload a clearer image') : null },
    });
    // Approval (and its push) happens in recompute once the identity check has passed too.
    await this.approval.recompute(params.driverId);
    if (params.status === 'REJECTED') void this.notifier.kycReviewed({ driverId: params.driverId, type: params.type, status: 'REJECTED', reason: params.reason });
    return this.prisma.kycDocument.findMany({ where: { driverId: params.driverId }, orderBy: { type: 'asc' } });
  }

  async trips(q: ListQueryDto): Promise<Paged<Omit<Trip, 'pathPolyline' | 'routePolyline'>>> {
    const { skip, take, page, pageSize } = paging(q);
    const where: Prisma.TripWhereInput = {
      status: q.status ? (q.status as Trip['status']) : undefined,
      kind: q.kind === 'RIDE' || q.kind === 'PARCEL' ? q.kind : undefined,
      needsReview: q.review === 'true' ? true : undefined,
      OR: q.q ? [{ id: { contains: q.q } }, { pickupName: { contains: q.q, mode: 'insensitive' } }, { dropName: { contains: q.q, mode: 'insensitive' } }] : undefined,
    };
    const [items, total] = await Promise.all([
      // The recorded path and the quoted route are only needed on the trip page.
      // The last cancellation's verdict, for the fault column of cancelled trips.
      this.prisma.trip.findMany({
        where,
        skip,
        take,
        orderBy: { createdAt: 'desc' },
        omit: { pathPolyline: true, routePolyline: true },
        include: {
          passenger: true,
          driver: { include: { user: true } },
          cancellations: { orderBy: { createdAt: 'desc' }, take: 1, select: { fault: true, faultRule: true, reassigned: true } },
        },
      }),
      this.prisma.trip.count({ where }),
    ]);
    return { items, total, page, pageSize };
  }

  /** Admin decision on a flagged trip. The note is kept after the flag's reason ("Reviewed: …"). */
  async reviewTrip(id: string, body: { needsReview: boolean; note?: string }): Promise<Trip> {
    const trip = await this.prisma.trip.findUniqueOrThrow({ where: { id }, select: { reviewNote: true } });
    const note = body.note?.trim();
    const label = body.needsReview ? 'Flagged' : 'Reviewed';
    return this.prisma.trip.update({
      where: { id },
      data: { needsReview: body.needsReview, reviewNote: note ? [trip.reviewNote, `${label}: ${note}`].filter(Boolean).join('; ') : undefined },
    });
  }

  trip(id: string): Promise<Trip> {
    return this.prisma.trip.findUniqueOrThrow({
      where: { id },
      include: {
        passenger: true,
        driver: { include: { user: true } },
        tickets: true,
        // Every cancel, including drivers who dropped the trip before another took it.
        cancellations: { orderBy: { createdAt: 'asc' }, include: { driver: { select: { id: true, plate: true, user: { select: { name: true } } } } } },
        // Safety: SOS alerts and signals (long stops, deviations, check-ins), newest first.
        sos: { orderBy: { createdAt: 'desc' } },
        safetyEvents: { orderBy: { at: 'desc' }, take: 50 },
      },
    });
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
