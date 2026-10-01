import { Injectable } from '@nestjs/common';

import { PrismaService } from '../../core/prisma/prisma.service.js';
import { driverSearch, userSearch } from './list-filters.js';

export interface SearchResults {
  readonly drivers: { id: string; userId: string; plate: string; vehicleKind: string; status: string; isOnline: boolean; user: { name: string | null; phone: string } }[];
  /** Accounts without a driver profile (riders and admins). */
  readonly people: { id: string; name: string | null; phone: string; role: string; isBlocked: boolean }[];
  readonly trips: { id: string; status: string; kind: string; pickupName: string; dropName: string; fareTotal: number; createdAt: Date }[];
}

const EMPTY: SearchResults = { drivers: [], people: [], trips: [] };

/** A trip id as typed: "#E0TVH8TX" (the short id the panel shows) or a full id. */
export function tripIdQuery(q: string): string | null {
  const id = q.trim().replace(/^#/, '').toLowerCase();
  return /^[a-z0-9]{6,30}$/.test(id) ? id : null;
}

/** The admin panel's global search (Ctrl+K): a few drivers, people and trips for one text. */
@Injectable()
export class AdminSearchService {
  constructor(private readonly prisma: PrismaService) {}

  async search(raw: string | undefined, take = 5): Promise<SearchResults> {
    const q = raw?.trim().slice(0, 60) ?? '';
    if (q.length < 2) return EMPTY;
    const tripId = tripIdQuery(q);
    const [drivers, people, trips] = await Promise.all([
      this.prisma.driver.findMany({
        where: driverSearch(q),
        take,
        orderBy: { createdAt: 'desc' },
        select: { id: true, userId: true, plate: true, vehicleKind: true, status: true, isOnline: true, user: { select: { name: true, phone: true } } },
      }),
      this.prisma.user.findMany({
        where: { driver: null, ...userSearch(q, true) },
        take,
        orderBy: { createdAt: 'desc' },
        select: { id: true, name: true, phone: true, role: true, isBlocked: true },
      }),
      this.prisma.trip.findMany({
        where: {
          OR: [
            ...(tripId ? [{ id: { endsWith: tripId } }, { id: tripId }] : []),
            { pickupName: { contains: q, mode: 'insensitive' } },
            { dropName: { contains: q, mode: 'insensitive' } },
          ],
        },
        take,
        orderBy: { createdAt: 'desc' },
        select: { id: true, status: true, kind: true, pickupName: true, dropName: true, fareTotal: true, createdAt: true },
      }),
    ]);
    return { drivers, people, trips };
  }
}
