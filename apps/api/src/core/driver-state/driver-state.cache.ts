import { Injectable } from '@nestjs/common';

import type { VehicleKind } from '../../generated/prisma/enums.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { RedisService } from '../redis/redis.service.js';

/** What the GPS path needs to know about a driver, without a database read per fix. */
export interface DriverState {
  readonly isOnline: boolean;
  readonly vehicleKind: VehicleKind;
  /** The driver's account is blocked by an admin (their fixes are ignored). */
  readonly isBlocked: boolean;
}

/** A cached entry lives this long; a change made elsewhere (e.g. a manual DB edit) shows within it. */
export const DRIVER_STATE_TTL_S = 60;

const key = (driverId: string): string => `driver:state:${driverId}`;

/** `1|BIKE|0` = online, BIKE, not blocked. */
function encode(s: DriverState): string {
  return `${s.isOnline ? 1 : 0}|${s.vehicleKind}|${s.isBlocked ? 1 : 0}`;
}

export function decodeDriverState(raw: string): DriverState | null {
  const [online, kind, blocked] = raw.split('|');
  if (!kind || (online !== '0' && online !== '1')) return null;
  return { isOnline: online === '1', vehicleKind: kind as VehicleKind, isBlocked: blocked === '1' };
}

/**
 * Redis cache of [DriverState] (`driver:state:<driverId>`, 60 s). Written on go online / offline, dropped whenever
 * the driver's status, vehicle or block flag changes (admin, KYC, profile edit); a miss reads the database.
 */
@Injectable()
export class DriverStateCache {
  constructor(
    private readonly prisma: PrismaService,
    private readonly redis: RedisService,
  ) {}

  async get(driverId: string): Promise<DriverState | null> {
    const raw = await this.redis.get(key(driverId));
    const cached = raw ? decodeDriverState(raw) : null;
    if (cached) return cached;
    const d = await this.prisma.driver.findUnique({
      where: { id: driverId },
      select: { isOnline: true, vehicleKind: true, user: { select: { isBlocked: true } } },
    });
    if (!d) return null;
    const state = { isOnline: d.isOnline, vehicleKind: d.vehicleKind, isBlocked: d.user.isBlocked };
    await this.redis.set(key(driverId), encode(state), 'EX', DRIVER_STATE_TTL_S);
    return state;
  }

  /** After go online / offline: the new state, read back from the row just written. */
  async set(driverId: string, state: DriverState): Promise<void> {
    await this.redis.set(key(driverId), encode(state), 'EX', DRIVER_STATE_TTL_S);
  }

  async invalidate(driverId: string): Promise<void> {
    await this.redis.del(key(driverId));
  }

  /** For changes made on the user (block / unblock). */
  async invalidateUser(userId: string): Promise<void> {
    const d = await this.prisma.driver.findUnique({ where: { userId }, select: { id: true } });
    if (d) await this.invalidate(d.id);
  }
}
