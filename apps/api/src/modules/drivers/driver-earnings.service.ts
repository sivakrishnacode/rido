import { Injectable } from '@nestjs/common';

import { PrismaService } from '../../core/prisma/prisma.service.js';
import { RedisService } from '../../core/redis/redis.service.js';
import { TripStatus } from '../../generated/prisma/enums.js';

export const EARNINGS_PERIODS = ['today', 'week', 'month'] as const;
export type EarningsPeriod = (typeof EARNINGS_PERIODS)[number];

const DAY_MS = 86_400_000;
const IST_MS = 5.5 * 3600_000;
/** Commission apps take about 30% of fares; Rido takes none (drivers pay a flat plan). */
const COMMISSION_RATE = 0.3;
const WEEKDAYS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
const HOUR_BUCKETS = [6, 8, 10, 12, 14, 16, 18, 20, 22];

export interface Earnings {
  period: EarningsPeriod;
  total: number;
  rides: number;
  onlineHours: number;
  rating: number;
  commissionSaved: number;
  bars: { label: string; amount: number; rides: number }[];
  trips: {
    id: string;
    at: string;
    from: string;
    to: string;
    fare: number;
    paymentMode: string;
    distanceKm: number;
    durationMin: number;
    passengerName: string;
    isDelivery: boolean;
  }[];
}

/** IST calendar day (yyyy-mm-dd) of [d]. */
export function istDay(d: Date): string {
  return new Date(d.getTime() + IST_MS).toISOString().slice(0, 10);
}

/** Start of the IST day containing [d], as a UTC instant. */
function istMidnight(d: Date): Date {
  const shifted = new Date(d.getTime() + IST_MS);
  shifted.setUTCHours(0, 0, 0, 0);
  return new Date(shifted.getTime() - IST_MS);
}

function hourLabel(h: number): string {
  const h12 = h % 12 === 0 ? 12 : h % 12;
  return `${h12} ${h < 12 ? 'AM' : 'PM'}`;
}

/**
 * Driver earnings (D-23): today in 2-hour buckets, the last 7 days, or the last 4 weeks. Online time is tracked
 * per IST day in Redis when the driver goes online / offline (no Google calls, no extra tables).
 */
@Injectable()
export class DriverEarningsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly redis: RedisService,
  ) {}

  async summary(driverId: string, period: EarningsPeriod, now = new Date()): Promise<Earnings> {
    const today = istMidnight(now);
    const days = period === 'today' ? 1 : period === 'week' ? 7 : 28;
    const from = new Date(today.getTime() - (days - 1) * DAY_MS);
    const [driver, trips] = await Promise.all([
      this.prisma.driver.findUniqueOrThrow({ where: { id: driverId }, select: { rating: true } }),
      this.prisma.trip.findMany({
        where: { driverId, status: { in: [TripStatus.COMPLETED, TripStatus.DELIVERED] }, endedAt: { gte: from } },
        orderBy: { endedAt: 'desc' },
        include: { passenger: { select: { name: true } } },
      }),
    ]);

    const bars =
      period === 'today'
        ? HOUR_BUCKETS.map((h) => ({ label: hourLabel(h), start: today.getTime() + h * 3600_000, end: today.getTime() + (h + 2) * 3600_000 }))
        : period === 'week'
          ? Array.from({ length: 7 }, (_, i) => {
              const start = from.getTime() + i * DAY_MS;
              return { label: WEEKDAYS[new Date(start + IST_MS).getUTCDay()], start, end: start + DAY_MS };
            })
          : Array.from({ length: 4 }, (_, i) => ({ label: `W${i + 1}`, start: from.getTime() + i * 7 * DAY_MS, end: from.getTime() + (i + 1) * 7 * DAY_MS }));
    const out = bars.map((b) => ({ label: b.label, amount: 0, rides: 0 }));
    for (const t of trips) {
      const at = t.endedAt!.getTime();
      // Trips before the first / after the last "today" bucket count in the nearest one.
      let i = bars.findIndex((b) => at >= b.start && at < b.end);
      if (i < 0) i = at < bars[0].start ? 0 : bars.length - 1;
      out[i].amount += t.fareTotal;
      out[i].rides++;
    }

    const total = trips.reduce((a, t) => a + t.fareTotal, 0);
    return {
      period,
      total,
      rides: trips.length,
      onlineHours: Math.round((await this.onlineSeconds(driverId, from, days, now)) / 360) / 10,
      rating: driver.rating,
      commissionSaved: Math.round((total * COMMISSION_RATE) / 10) * 10,
      bars: out,
      trips: trips.slice(0, 50).map((t) => ({
        id: t.id,
        at: t.endedAt!.toISOString(),
        from: t.pickupName,
        to: t.dropName,
        fare: t.fareTotal,
        paymentMode: t.paymentMode,
        distanceKm: t.distanceKm,
        durationMin: t.startedAt && t.endedAt ? Math.max(1, Math.round((t.endedAt.getTime() - t.startedAt.getTime()) / 60_000)) : t.durationMin,
        passengerName: t.passenger.name ?? 'Rido customer',
        isDelivery: t.kind === 'PARCEL',
      })),
    };
  }

  /** Called when the driver goes online. */
  async sessionStarted(driverId: string, now = new Date()): Promise<void> {
    await this.redis.set(`driver:online_since:${driverId}`, String(now.getTime()), 'NX');
  }

  /** Called when the driver goes offline: adds the session to its IST day. */
  async sessionEnded(driverId: string, now = new Date()): Promise<void> {
    const since = Number(await this.redis.getdel(`driver:online_since:${driverId}`));
    if (!since) return;
    const key = `driver:online_secs:${driverId}:${istDay(new Date(since))}`;
    await this.redis.incrby(key, Math.max(0, Math.round((now.getTime() - since) / 1000)));
    await this.redis.expire(key, 40 * 86_400);
  }

  private async onlineSeconds(driverId: string, from: Date, days: number, now: Date): Promise<number> {
    const keys = Array.from({ length: days }, (_, i) => `driver:online_secs:${driverId}:${istDay(new Date(from.getTime() + i * DAY_MS + DAY_MS / 2))}`);
    const [values, since] = await Promise.all([this.redis.mget(...keys), this.redis.get(`driver:online_since:${driverId}`)]);
    const open = since ? Math.max(0, (now.getTime() - Math.max(Number(since), from.getTime())) / 1000) : 0;
    return values.reduce((a, v) => a + Number(v ?? 0), 0) + open;
  }
}
