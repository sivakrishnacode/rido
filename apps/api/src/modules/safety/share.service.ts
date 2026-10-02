import { ForbiddenException, GoneException, Inject, Injectable, NotFoundException } from '@nestjs/common';

import type { Env } from '../../core/config/env.js';
import { ENV } from '../../core/config/env.token.js';
import { PrismaService } from '../../core/prisma/prisma.service.js';
import { rateLimit } from '../../core/rate-limit/rate-limit.js';
import { RedisService } from '../../core/redis/redis.service.js';
import type { Trip } from '../../generated/prisma/client.js';
import { TripStatus, type TripKind, type VehicleKind } from '../../generated/prisma/enums.js';
import { DriverLocationService } from '../drivers/driver-location.service.js';
import { etaMinutes, FALLBACK_KMH, roadKm } from '../geo/eta-model.js';
import { isShareLive, shareExpiry, signShareToken, verifyShareToken } from './share-token.js';

/** Public reads per IP and per link, per minute (the page polls every ~5 s; a family may watch together). */
export const SHARE_READS_PER_IP = 60;
export const SHARE_READS_PER_TOKEN = 240;

/** A share link for the passenger to send (SMS, WhatsApp, the share sheet). */
export interface ShareLink {
  readonly url: string;
  readonly token: string;
  readonly expiresAt: string;
}

/** What anyone with the link sees: no phone numbers, no names beyond the driver's first name, no OTP. */
export interface ShareView {
  readonly status: TripStatus;
  readonly kind: TripKind;
  /** The trip is still running (the page keeps polling). */
  readonly isLive: boolean;
  readonly driver: { readonly firstName: string; readonly vehicleKind: VehicleKind; readonly vehicleModel: string; readonly vehicleColor: string; readonly plate: string } | null;
  /** The driver's last GPS fix while the trip runs. */
  readonly location: { readonly lat: number; readonly lng: number; readonly at: number | null } | null;
  readonly pickup: { readonly name: string; readonly lat: number; readonly lng: number };
  readonly drop: { readonly name: string; readonly lat: number; readonly lng: number };
  /** Straight-line estimate (free) to the pickup before the start, to the drop after it. */
  readonly etaMin: number | null;
  readonly etaTo: 'pickup' | 'drop' | null;
  readonly expiresAt: string;
}

const ACTIVE: readonly TripStatus[] = [TripStatus.DRIVER_ASSIGNED, TripStatus.DRIVER_ARRIVED, TripStatus.IN_PROGRESS, TripStatus.PICKED_UP];
const RIDING: readonly TripStatus[] = [TripStatus.IN_PROGRESS, TripStatus.PICKED_UP];

/** When the trip ended (completed, delivered, cancelled, no drivers), or null while it runs. */
export function tripEnd(trip: Pick<Trip, 'status' | 'endedAt' | 'cancelledAt' | 'createdAt'>): Date | null {
  if (trip.endedAt) return trip.endedAt;
  if (trip.cancelledAt) return trip.cancelledAt;
  if (trip.status === TripStatus.NO_DRIVERS || trip.status === TripStatus.COMPLETED || trip.status === TripStatus.DELIVERED || trip.status === TripStatus.CANCELLED) {
    return trip.createdAt;
  }
  return null;
}

type TripForView = Trip & { driver: { plate: string; vehicleKind: VehicleKind; vehicleModel: string; vehicleColor: string; user: { name: string | null } } | null };

/** Maps a trip (and the driver's last fix) to the public [ShareView]. */
export function shareView(trip: TripForView, fix: { lat: number; lng: number; at: number | null } | null, expiresAt: number): ShareView {
  const isLive = tripEnd(trip) === null;
  const location = isLive && ACTIVE.includes(trip.status) ? fix : null;
  const etaTo = !location ? null : RIDING.includes(trip.status) ? 'drop' : 'pickup';
  const target = etaTo === 'drop' ? { lat: trip.dropLat, lng: trip.dropLng } : { lat: trip.pickupLat, lng: trip.pickupLng };
  const d = trip.driver;
  return {
    status: trip.status,
    kind: trip.kind,
    isLive,
    driver: d
      ? { firstName: (d.user.name ?? '').trim().split(/\s+/)[0] || 'Your driver', vehicleKind: d.vehicleKind, vehicleModel: d.vehicleModel, vehicleColor: d.vehicleColor, plate: d.plate }
      : null,
    location,
    pickup: { name: trip.pickupName, lat: trip.pickupLat, lng: trip.pickupLng },
    drop: { name: trip.dropName, lat: trip.dropLat, lng: trip.dropLng },
    etaMin: location && etaTo ? etaMinutes(roadKm(location, target), FALLBACK_KMH) : null,
    etaTo,
    expiresAt: new Date(expiresAt).toISOString(),
  };
}

/**
 * Live trip links (like Namma Yatri's "share ride"): the passenger gets a signed token (HMAC of the JWT secret, no
 * table), valid until 30 min after the trip ends. `GET /share/:token` is public and rate limited; the admin app's
 * `/track/<token>` page polls it.
 */
@Injectable()
export class ShareService {
  constructor(
    @Inject(ENV) private readonly env: Env,
    private readonly prisma: PrismaService,
    private readonly redis: RedisService,
    private readonly location: DriverLocationService,
  ) {}

  /** A link to [tripId] for its passenger (or its driver, for an SOS). */
  async create(user: { userId: string; driverId?: string }, tripId: string, allowDriver = false): Promise<ShareLink> {
    const trip = await this.prisma.trip.findUnique({ where: { id: tripId } });
    if (!trip) throw new NotFoundException('Trip not found');
    const isPassenger = trip.passengerId === user.userId;
    const isDriver = allowDriver && !!user.driverId && trip.driverId === user.driverId;
    if (!isPassenger && !isDriver) throw new ForbiddenException();
    return this.linkFor(trip);
  }

  linkFor(trip: Pick<Trip, 'id' | 'status' | 'endedAt' | 'cancelledAt' | 'createdAt'>): ShareLink {
    const exp = shareExpiry(tripEnd(trip));
    if (exp <= Date.now()) throw new GoneException('This trip ended more than 30 minutes ago');
    const token = signShareToken({ tripId: trip.id, exp }, this.env.jwtSecret);
    return { url: `${this.env.shareBaseUrl}/track/${token}`, token, expiresAt: new Date(exp).toISOString() };
  }

  /** The public view of a link. 404 for a bad token, 410 once expired. */
  async view(token: string, ip: string): Promise<ShareView> {
    await rateLimit(this.redis, `share:ip:${ip}`, SHARE_READS_PER_IP, 60);
    const claims = verifyShareToken(token, this.env.jwtSecret);
    if (!claims) {
      // Tell an expired link apart from a wrong one (the page says "This trip has ended").
      const parts = token.split('.');
      const exp = parts.length === 3 ? parseInt(parts[1], 36) : NaN;
      if (Number.isFinite(exp) && exp <= Date.now() && verifyShareToken(token, this.env.jwtSecret, exp - 1)) throw new GoneException('This link has expired');
      throw new NotFoundException('Link not found');
    }
    await rateLimit(this.redis, `share:tok:${claims.tripId}`, SHARE_READS_PER_TOKEN, 60);
    const trip = await this.prisma.trip.findUnique({
      where: { id: claims.tripId },
      include: { driver: { select: { plate: true, vehicleKind: true, vehicleModel: true, vehicleColor: true, user: { select: { name: true } } } } },
    });
    if (!trip) throw new NotFoundException('Link not found');
    const end = tripEnd(trip);
    if (!isShareLive(end)) throw new GoneException('This trip has ended');
    const fix = trip.driverId && end === null ? await this.location.lastFix(trip.driverId) : null;
    return shareView(trip, fix, Math.min(claims.exp, shareExpiry(end)));
  }
}
