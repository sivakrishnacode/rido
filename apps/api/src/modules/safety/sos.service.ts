import { BadRequestException, ConflictException, ForbiddenException, Injectable, Logger, NotFoundException } from '@nestjs/common';

import { PrismaService } from '../../core/prisma/prisma.service.js';
import type { Prisma, Sos } from '../../generated/prisma/client.js';
import { SafetyEventKind, SafetyParty, SosStatus } from '../../generated/prisma/enums.js';
import { DriverLocationService } from '../drivers/driver-location.service.js';
import { NotifierService } from '../notifications/notifier.service.js';
import { SettingsService } from '../settings/settings.service.js';
import { ShareService, tripEnd } from './share.service.js';

/** SOS is allowed during a trip and up to this long after it ended (e.g. "Did you reach safely?" → No). */
export const SOS_AFTER_END_MS = 6 * 3600_000;
/** A second SOS by the same person on the same trip within this window returns the first (double taps, retries). */
export const SOS_DEDUPE_MS = 2 * 60_000;

/** What raised an SOS. */
export type SosSource = 'BUTTON' | 'CHECK' | 'ARRIVAL';

/** POST /trips/:id/sos answer: the SOS and a live link to text to emergency contacts. */
export interface SosResult {
  readonly sos: Sos;
  readonly shareUrl: string | null;
  readonly shareExpiresAt: string | null;
}

type Caller = { userId: string; driverId?: string };

/**
 * SOS from the apps (like Namma Yatri's Safety `Sos` table): a row per alert with where they were, a SOS_LINKED
 * safety event on the trip, a push to every admin (setting `sosAdminAlert`) and a live share link for the caller to
 * send by SMS. Admins acknowledge and resolve it on the admin SOS page (audit logged).
 */
@Injectable()
export class SosService {
  private readonly logger = new Logger(SosService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly location: DriverLocationService,
    private readonly notifier: NotifierService,
    private readonly settings: SettingsService,
    private readonly share: ShareService,
  ) {}

  async create(user: Caller, tripId: string, body: { lat?: number; lng?: number; note?: string }, source: SosSource = 'BUTTON'): Promise<SosResult> {
    const trip = await this.prisma.trip.findUnique({ where: { id: tripId }, include: { passenger: { select: { name: true } }, driver: { select: { user: { select: { name: true } } } } } });
    if (!trip) throw new NotFoundException('Trip not found');
    const role = trip.passengerId === user.userId ? SafetyParty.PASSENGER : user.driverId && trip.driverId === user.driverId ? SafetyParty.DRIVER : null;
    if (!role) throw new ForbiddenException();
    const end = tripEnd(trip);
    if (end && Date.now() - end.getTime() > SOS_AFTER_END_MS) throw new BadRequestException('This trip ended a while ago. Call 112 or Rido support');

    const recent = await this.prisma.sos.findFirst({
      where: { tripId, userId: user.userId, status: { in: [SosStatus.OPEN, SosStatus.ACKNOWLEDGED] }, createdAt: { gte: new Date(Date.now() - SOS_DEDUPE_MS) } },
      orderBy: { createdAt: 'desc' },
    });
    const sos = recent ?? (await this.record(trip.id, user.userId, role, await this.where(body, trip.driverId, end === null), source, body.note));
    if (!recent) {
      const name = role === SafetyParty.DRIVER ? (trip.driver?.user.name ?? null) : trip.passenger.name;
      if (await this.settings.get('sosAdminAlert')) {
        void this.notifier.sosAlert({ sosId: sos.id, tripId: trip.id, who: role, name, source, lat: sos.lat, lng: sos.lng });
      }
      this.logger.warn(`SOS ${sos.id} (${role}, ${source}) on trip ${trip.id}`);
    }
    let link: { url: string; expiresAt: string } | null = null;
    try {
      link = this.share.linkFor(trip);
    } catch {
      link = null; // the trip ended more than 30 min ago: no live link any more
    }
    return { sos, shareUrl: link?.url ?? null, shareExpiresAt: link?.expiresAt ?? null };
  }

  /** The phone's fix, else the driver's last GPS fix while the trip runs (the passenger rides with them). */
  private async where(body: { lat?: number; lng?: number }, driverId: string | null, isRunning: boolean): Promise<{ lat: number | null; lng: number | null }> {
    if (body.lat !== undefined && body.lng !== undefined) return { lat: body.lat, lng: body.lng };
    const fix = driverId && isRunning ? await this.location.position(driverId).catch(() => null) : null;
    return { lat: fix?.lat ?? null, lng: fix?.lng ?? null };
  }

  private record(tripId: string, userId: string, role: SafetyParty, at: { lat: number | null; lng: number | null }, source: SosSource, note?: string): Promise<Sos> {
    return this.prisma.$transaction(async (tx) => {
      const sos = await tx.sos.create({ data: { tripId, userId, role, source, note: note?.trim() || null, ...at } });
      await tx.safetyEvent.create({ data: { tripId, kind: SafetyEventKind.SOS_LINKED, payload: { sosId: sos.id, role, source } } });
      return sos;
    });
  }

  /**
   * The passenger answered a safety check: the answer is kept on its event; "HELP" raises an SOS (source CHECK, or
   * ARRIVAL for "Did you reach safely?"), so admins are alerted.
   */
  async answerCheck(user: Caller, tripId: string, body: { answer: 'OK' | 'HELP'; eventId?: string; lat?: number; lng?: number }): Promise<{ answer: 'OK' | 'HELP'; sos: SosResult | null }> {
    const trip = await this.prisma.trip.findUnique({ where: { id: tripId }, select: { passengerId: true } });
    if (!trip) throw new NotFoundException('Trip not found');
    if (trip.passengerId !== user.userId) throw new ForbiddenException();
    let source: SosSource = 'CHECK';
    let what = 'safety check';
    if (body.eventId) {
      const event = await this.prisma.safetyEvent.findFirst({ where: { id: body.eventId, tripId } });
      if (!event) throw new NotFoundException('Safety check not found');
      const payload = (event.payload ?? {}) as Record<string, unknown>;
      if (event.kind === SafetyEventKind.NIGHT_CHECK && payload.check === 'SAFE_ARRIVAL') source = 'ARRIVAL';
      what = event.kind === SafetyEventKind.STOP ? 'long stop' : event.kind === SafetyEventKind.DEVIATION ? 'route change' : source === 'ARRIVAL' ? 'reached safely?' : 'night check';
      await this.prisma.safetyEvent.update({
        where: { id: event.id },
        data: { payload: { ...payload, answer: body.answer, answeredAt: new Date().toISOString() } as Prisma.InputJsonValue },
      });
    }
    if (body.answer === 'OK') return { answer: 'OK', sos: null };
    const note = source === 'ARRIVAL' ? 'Answered "No / Need help" to "Did you reach safely?"' : `Asked for help after the ${what} check`;
    return { answer: 'HELP', sos: await this.create(user, tripId, { lat: body.lat, lng: body.lng, note }, source) };
  }

  // ------------------------------------------------------------------------------------------------ admin

  /** Newest first; ?status=OPEN|ACKNOWLEDGED|RESOLVED|FALSE_ALARM, or "active" (open + acknowledged). */
  async list(q: { status?: string; page?: number; pageSize?: number }) {
    const page = q.page ?? 1;
    const pageSize = q.pageSize ?? 20;
    const status =
      q.status === 'active'
        ? { in: [SosStatus.OPEN, SosStatus.ACKNOWLEDGED] }
        : q.status && (Object.values(SosStatus) as string[]).includes(q.status)
          ? (q.status as SosStatus)
          : undefined;
    const where: Prisma.SosWhereInput = { status };
    const [items, total, open] = await Promise.all([
      this.prisma.sos.findMany({
        where,
        // Open ones first, then newest.
        orderBy: [{ status: 'asc' }, { createdAt: 'desc' }],
        skip: (page - 1) * pageSize,
        take: pageSize,
        include: {
          user: { select: { id: true, name: true, phone: true } },
          trip: {
            select: {
              id: true, status: true, kind: true, pickupName: true, dropName: true,
              passenger: { select: { name: true, phone: true } },
              driver: { select: { id: true, plate: true, user: { select: { name: true, phone: true } } } },
            },
          },
        },
      }),
      this.prisma.sos.count({ where }),
      this.prisma.sos.count({ where: { status: SosStatus.OPEN } }),
    ]);
    return { items, total, page, pageSize, open };
  }

  /** Someone at Rido is on it. Only an OPEN SOS can be acknowledged (409 otherwise). */
  async acknowledge(id: string, adminId: string): Promise<Sos> {
    const { count } = await this.prisma.sos.updateMany({
      where: { id, status: SosStatus.OPEN },
      data: { status: SosStatus.ACKNOWLEDGED, acknowledgedAt: new Date(), acknowledgedBy: adminId },
    });
    if (count === 0) await this.conflictOrMissing(id, 'This SOS is no longer open');
    return this.prisma.sos.findUniqueOrThrow({ where: { id } });
  }

  /** Closes it as RESOLVED or FALSE_ALARM with a note (an open one is acknowledged at the same time). */
  async resolve(id: string, adminId: string, body: { status: 'RESOLVED' | 'FALSE_ALARM'; note?: string }): Promise<Sos> {
    const now = new Date();
    const sos = await this.prisma.sos.findUnique({ where: { id } });
    if (!sos) throw new NotFoundException('SOS not found');
    const { count } = await this.prisma.sos.updateMany({
      where: { id, status: { in: [SosStatus.OPEN, SosStatus.ACKNOWLEDGED] } },
      data: {
        status: body.status,
        resolvedAt: now,
        resolvedBy: adminId,
        acknowledgedAt: sos.acknowledgedAt ?? now,
        acknowledgedBy: sos.acknowledgedBy ?? adminId,
        note: body.note ? [sos.note, body.note.trim()].filter(Boolean).join(' · ') : undefined,
      },
    });
    if (count === 0) throw new ConflictException('This SOS is already closed');
    return this.prisma.sos.findUniqueOrThrow({ where: { id } });
  }

  private async conflictOrMissing(id: string, message: string): Promise<never> {
    if (!(await this.prisma.sos.findUnique({ where: { id }, select: { id: true } }))) throw new NotFoundException('SOS not found');
    throw new ConflictException(message);
  }
}
