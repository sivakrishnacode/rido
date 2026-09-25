import { Injectable } from '@nestjs/common';

import { PrismaService } from '../../core/prisma/prisma.service.js';
import type { Place } from '../../generated/prisma/client.js';
import { haversineMeters } from '../fares/fare-engine.js';
import type { PlaceSuggestion, ResolvedPlace } from '../maps/google-maps.client.js';
import { GeoService } from '../geo/geo.service.js';
import { MapsService } from '../maps/maps.service.js';

/** Place search and reverse geocoding: Google when configured, seeded places otherwise. */
@Injectable()
export class PlacesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly maps: MapsService,
    private readonly geo: GeoService,
  ) {}

  /** Seeded places matching [query] (also the offline fallback). */
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

  /** Google Places Autocomplete; falls back to seeded search (ids prefixed "local:"). */
  async autocomplete(params: { input: string; sessionToken: string }): Promise<{ source: 'google' | 'local'; results: PlaceSuggestion[] }> {
    const google = await this.maps.autocomplete(params);
    if (google) return { source: 'google', results: google };
    const local = await this.search(params.input);
    return { source: 'local', results: local.map((p) => ({ placeId: `local:${p.id}`, name: p.name, address: p.address })) };
  }

  /** Coordinates for an autocomplete result (ends the Google session). */
  async details(params: { placeId: string; sessionToken?: string }): Promise<ResolvedPlace | null> {
    if (params.placeId.startsWith('local:')) {
      const p = await this.prisma.place.findUnique({ where: { id: params.placeId.slice(6) } });
      return p ? { placeId: `local:${p.id}`, name: p.name, address: p.address, lat: p.lat, lng: p.lng } : null;
    }
    return this.maps.details(params);
  }

  async reverse(point: { lat: number; lng: number }): Promise<{ place: ResolvedPlace | null; isInServiceArea: boolean }> {
    const isInServiceArea = (await this.geo.locate(point)).isServiceable;
    const google = await this.maps.reverseGeocode(point);
    if (google) return { place: google, isInServiceArea };
    const places = await this.prisma.place.findMany();
    const nearest = places.reduce<Place | null>(
      (best, p) => (!best || haversineMeters(p, point) < haversineMeters(best, point) ? p : best),
      null,
    );
    const place = nearest ? { placeId: `local:${nearest.id}`, name: nearest.name, address: nearest.address, ...point } : null;
    return { place, isInServiceArea };
  }
}
