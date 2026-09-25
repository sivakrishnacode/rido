import { Injectable } from '@nestjs/common';

import { PrismaService } from '../../core/prisma/prisma.service.js';
import type { Place } from '../../generated/prisma/client.js';
import { haversineMeters } from '../fares/fare-engine.js';

/** Coimbatore service area: 18 km around the city centre. */
const CITY_CENTRE = { lat: 11.0168, lng: 76.9658 } as const;
const SERVICE_RADIUS_M = 18_000;

/** Place search and reverse geocoding over the seeded places table. */
@Injectable()
export class PlacesService {
  constructor(private readonly prisma: PrismaService) {}

  search(query: string): Promise<Place[]> {
    const q = query.trim();
    return this.prisma.place.findMany({
      where: q
        ? { OR: [{ name: { contains: q, mode: 'insensitive' } }, { address: { contains: q, mode: 'insensitive' } }] }
        : {},
      take: 10,
      orderBy: { name: 'asc' },
    });
  }

  async reverse(point: { lat: number; lng: number }): Promise<{ place: Place | null; isInServiceArea: boolean }> {
    const places = await this.prisma.place.findMany();
    const nearest = places.reduce<Place | null>(
      (best, p) => (!best || haversineMeters(p, point) < haversineMeters(best, point) ? p : best),
      null,
    );
    return { place: nearest, isInServiceArea: haversineMeters(CITY_CENTRE, point) <= SERVICE_RADIUS_M };
  }
}
