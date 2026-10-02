import { Injectable } from '@nestjs/common';

import { PrismaService } from '../../core/prisma/prisma.service.js';
import { RedisService } from '../../core/redis/redis.service.js';
import type { Announcement, AuditLog, CancellationDue, Payment, Prisma } from '../../generated/prisma/client.js';
import { PaymentStatus, TripStatus } from '../../generated/prisma/enums.js';
import { toCsv } from './csv.js';
import type { Paged } from './admin.types.js';
import type { CreateAnnouncementDto } from './dto/announcement.dto.js';
import type { ListQueryDto } from './dto/list-query.dto.js';
import { NotifierService } from '../notifications/notifier.service.js';

/** A driver dot on the live map. */
export interface LiveDriver {
  readonly driverId: string;
  readonly name: string | null;
  readonly vehicleKind: string;
  readonly plate: string;
  readonly lat: number;
  readonly lng: number;
  readonly activeTripId: string | null;
}

const ACTIVE: TripStatus[] = [TripStatus.SEARCHING, TripStatus.DRIVER_ASSIGNED, TripStatus.DRIVER_ARRIVED, TripStatus.IN_PROGRESS, TripStatus.PICKED_UP];

/** Live operations, payments, announcements, audit log and CSV export. */
@Injectable()
export class AdminOpsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly redis: RedisService,
    private readonly notifier: NotifierService,
  ) {}

  /** Online drivers with their last GPS fix, plus active trips. */
  async live(): Promise<{ drivers: LiveDriver[]; trips: unknown[] }> {
    const online = await this.prisma.driver.findMany({ where: { isOnline: true }, include: { user: { select: { name: true } } } });
    const drivers: LiveDriver[] = [];
    for (const d of online) {
      const [pos, busy] = await Promise.all([this.redis.get(`driver:alive:${d.id}`), this.redis.get(`driver:busy:${d.id}`)]);
      if (!pos) continue;
      const [lat, lng] = pos.split(',').map(Number);
      drivers.push({ driverId: d.id, name: d.user.name, vehicleKind: d.vehicleKind, plate: d.plate, lat, lng, activeTripId: busy });
    }
    const trips = await this.prisma.trip.findMany({
      where: { status: { in: ACTIVE } }, orderBy: { createdAt: 'desc' }, take: 200,
      select: { id: true, kind: true, status: true, vehicleKind: true, pickupName: true, pickupLat: true, pickupLng: true, dropName: true, dropLat: true, dropLng: true, fareTotal: true, driverId: true, createdAt: true },
    });
    return { drivers, trips };
  }

  async payments(q: ListQueryDto): Promise<Paged<Payment>> {
    const page = q.page ?? 1;
    const pageSize = q.pageSize ?? 20;
    const status = q.status && (Object.values(PaymentStatus) as string[]).includes(q.status) ? (q.status as PaymentStatus) : undefined;
    const where: Prisma.PaymentWhereInput = { status };
    const [items, total] = await Promise.all([
      this.prisma.payment.findMany({
        where, skip: (page - 1) * pageSize, take: pageSize, orderBy: { createdAt: 'desc' },
        include: { subscription: { include: { plan: true, driver: { include: { user: { select: { name: true, phone: true } } } } } } },
      }),
      this.prisma.payment.count({ where }),
    ]);
    return { items, total, page, pageSize };
  }

  /**
   * Cancellation fees (report only, no settlement): who owed whom, for which cancelled trip, and the ride whose
   * fare collected it (its driver took the cash). `?status=PENDING|APPLIED`. [totals]: sums per status.
   */
  async cancellationDues(q: ListQueryDto): Promise<Paged<CancellationDue> & { totals: { pending: number; applied: number } }> {
    const page = q.page ?? 1;
    const pageSize = q.pageSize ?? 20;
    const status = q.status === 'PENDING' || q.status === 'APPLIED' ? q.status : undefined;
    const where: Prisma.CancellationDueWhereInput = { status };
    const person = { select: { id: true, name: true, phone: true } } as const;
    const driver = { select: { id: true, plate: true, user: { select: { name: true, phone: true } } } } as const;
    const [items, total, sums] = await Promise.all([
      this.prisma.cancellationDue.findMany({
        where,
        skip: (page - 1) * pageSize,
        take: pageSize,
        orderBy: { createdAt: 'desc' },
        include: {
          passenger: person,
          owedTo: driver,
          trip: { select: { id: true, createdAt: true, cancelledAt: true, pickupName: true } },
          appliedTrip: { select: { id: true, endedAt: true, driver } },
        },
      }),
      this.prisma.cancellationDue.count({ where }),
      this.prisma.cancellationDue.groupBy({ by: ['status'], _sum: { amount: true } }),
    ]);
    const sum = (s: string) => sums.find((x) => x.status === s)?._sum.amount ?? 0;
    return { items, total, page, pageSize, totals: { pending: sum('PENDING'), applied: sum('APPLIED') } };
  }

  announcements(): Promise<Announcement[]> {
    return this.prisma.announcement.findMany({ orderBy: { createdAt: 'desc' } });
  }

  /** Also pushed to the audience's topic (announcements scheduled for later are shown in-app only). */
  async createAnnouncement(dto: CreateAnnouncementDto): Promise<Announcement> {
    const a = await this.prisma.announcement.create({ data: { ...dto, endsAt: dto.endsAt ? new Date(dto.endsAt) : undefined } });
    this.notifier.announcement(a);
    return a;
  }

  async setAnnouncementActive(id: string, isActive: boolean): Promise<Announcement> {
    return this.prisma.announcement.update({ where: { id }, data: { isActive } });
  }

  async removeAnnouncement(id: string): Promise<void> {
    await this.prisma.announcement.delete({ where: { id } });
  }

  async audit(q: ListQueryDto): Promise<Paged<AuditLog>> {
    const page = q.page ?? 1;
    const pageSize = q.pageSize ?? 50;
    const where: Prisma.AuditLogWhereInput = { entity: q.kind || undefined, action: q.q ? { contains: q.q } : undefined };
    const [items, total] = await Promise.all([
      this.prisma.auditLog.findMany({ where, skip: (page - 1) * pageSize, take: pageSize, orderBy: { createdAt: 'desc' } }),
      this.prisma.auditLog.count({ where }),
    ]);
    return { items, total, page, pageSize };
  }

  /** CSV export of trips, drivers or payments (latest 5,000 rows; formula-looking text neutralised, csv.ts). */
  async exportCsv(entity: 'trips' | 'drivers' | 'payments'): Promise<string> {
    return toCsv(await this.rowsFor(entity));
  }

  private async rowsFor(entity: 'trips' | 'drivers' | 'payments'): Promise<Record<string, unknown>[]> {
    if (entity === 'trips') {
      return this.prisma.trip.findMany({
        take: 5000, orderBy: { createdAt: 'desc' },
        select: { id: true, createdAt: true, kind: true, status: true, vehicleKind: true, pickupName: true, dropName: true, distanceKm: true, durationMin: true, fareTotal: true, paymentMode: true, passengerId: true, driverId: true, rating: true, cancelledBy: true, cancelCode: true, cancelReason: true, cancelledAt: true },
      });
    }
    if (entity === 'drivers') {
      const drivers = await this.prisma.driver.findMany({ take: 5000, orderBy: { createdAt: 'desc' }, include: { user: { select: { name: true, phone: true } } } });
      return drivers.map((d) => ({ id: d.id, name: d.user.name, phone: d.user.phone, workType: d.workType, vehicleKind: d.vehicleKind, plate: d.plate, status: d.status, rating: d.rating, rides: d.ridesCount, upiId: d.upiId, createdAt: d.createdAt }));
    }
    const payments = await this.prisma.payment.findMany({ take: 5000, orderBy: { createdAt: 'desc' }, include: { subscription: { include: { plan: true } } } });
    return payments.map((p) => ({ id: p.id, createdAt: p.createdAt, amount: p.amount, status: p.status, provider: p.provider, providerRef: p.providerRef, driverId: p.subscription.driverId, vehicleKind: p.subscription.plan.vehicleKind, period: p.subscription.plan.period }));
  }
}
