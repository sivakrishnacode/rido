import { Injectable } from '@nestjs/common';

import { PrismaService } from '../../core/prisma/prisma.service.js';
import { RedisService } from '../../core/redis/redis.service.js';
import type { Announcement, AuditLog, Payment, Prisma } from '../../generated/prisma/client.js';
import { TripStatus } from '../../generated/prisma/enums.js';
import type { Paged } from './admin.types.js';
import type { CreateAnnouncementDto } from './dto/announcement.dto.js';
import type { ListQueryDto } from './dto/list-query.dto.js';

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
    const where: Prisma.PaymentWhereInput = { status: q.status ? (q.status as Payment['status']) : undefined };
    const [items, total] = await Promise.all([
      this.prisma.payment.findMany({
        where, skip: (page - 1) * pageSize, take: pageSize, orderBy: { createdAt: 'desc' },
        include: { subscription: { include: { plan: true, driver: { include: { user: { select: { name: true, phone: true } } } } } } },
      }),
      this.prisma.payment.count({ where }),
    ]);
    return { items, total, page, pageSize };
  }

  announcements(): Promise<Announcement[]> {
    return this.prisma.announcement.findMany({ orderBy: { createdAt: 'desc' } });
  }

  createAnnouncement(dto: CreateAnnouncementDto): Promise<Announcement> {
    return this.prisma.announcement.create({ data: { ...dto, endsAt: dto.endsAt ? new Date(dto.endsAt) : undefined } });
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

  /** CSV export of trips, drivers or payments (latest 5,000 rows). */
  async exportCsv(entity: 'trips' | 'drivers' | 'payments'): Promise<string> {
    const rows = await this.rowsFor(entity);
    if (rows.length === 0) return '';
    const headers = Object.keys(rows[0]);
    const esc = (v: unknown): string => {
      const s = v instanceof Date ? v.toISOString() : String(v ?? '');
      return /[",\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
    };
    return [headers.join(','), ...rows.map((r) => headers.map((h) => esc(r[h])).join(','))].join('\n');
  }

  private async rowsFor(entity: 'trips' | 'drivers' | 'payments'): Promise<Record<string, unknown>[]> {
    if (entity === 'trips') {
      return this.prisma.trip.findMany({
        take: 5000, orderBy: { createdAt: 'desc' },
        select: { id: true, createdAt: true, kind: true, status: true, vehicleKind: true, pickupName: true, dropName: true, distanceKm: true, durationMin: true, fareTotal: true, paymentMode: true, passengerId: true, driverId: true, rating: true, cancelReason: true },
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
