import { Injectable } from '@nestjs/common';

import { PrismaService } from '../../core/prisma/prisma.service.js';
import type { City, CityFareRule, Zone } from '../../generated/prisma/client.js';
import { VehicleKind, ZoneKind } from '../../generated/prisma/enums.js';
import { SettingsService } from '../settings/settings.service.js';
import { cellAt } from './h3.util.js';

interface CityIndex {
  readonly city: City & { zones: Zone[]; fareRules: CityFareRule[] };
  readonly service: ReadonlySet<string>;
}

/** Where a point is: its city, H3 cell, zones and whether Rido serves it. */
export interface PointInfo {
  readonly cityId: string | null;
  readonly cell: string | null;
  readonly isServiceable: boolean;
  readonly zones: readonly Zone[];
  /** Fare multiplier here (max of SURGE zones, else the platform default), capped by maxMultiplier. */
  readonly multiplier: number;
}

const CACHE_MS = 30_000;

/**
 * H3-based service areas. Cities and zones are cached in memory (30 s, or until [invalidate]
 * after an admin change) so every fare quote and booking can check them cheaply.
 */
@Injectable()
export class GeoService {
  private cache: { at: number; cities: CityIndex[] } | null = null;

  constructor(
    private readonly prisma: PrismaService,
    private readonly settings: SettingsService,
  ) {}

  invalidate(): void {
    this.cache = null;
  }

  private async cities(): Promise<CityIndex[]> {
    if (this.cache && Date.now() - this.cache.at < CACHE_MS) return this.cache.cities;
    const rows = await this.prisma.city.findMany({
      where: { isActive: true },
      include: { zones: { where: { isActive: true } }, fareRules: { where: { isActive: true } } },
    });
    const cities = rows.map((city) => ({ city, service: new Set(city.serviceCells) }));
    this.cache = { at: Date.now(), cities };
    return cities;
  }

  /** Looks up a point. With no cities configured, everything is serviceable (prototype default). */
  async locate(point: { lat: number; lng: number }): Promise<PointInfo> {
    const s = await this.settings.all();
    const cities = await this.cities();
    if (cities.length === 0) return { cityId: null, cell: null, isServiceable: true, zones: [], multiplier: s.currentMultiplier };
    for (const { city, service } of cities) {
      const cell = cellAt(point.lat, point.lng, city.h3Resolution);
      if (!service.has(cell)) continue;
      const zones = city.zones.filter((z) => z.cells.includes(cell));
      const isBlocked = zones.some((z) => z.kind === ZoneKind.NO_SERVICE);
      const surge = zones.filter((z) => z.kind === ZoneKind.SURGE).map((z) => z.surgeMultiplier);
      const multiplier = Math.min(s.maxMultiplier, Math.max(1, surge.length ? Math.max(...surge) : s.currentMultiplier));
      return { cityId: city.id, cell, isServiceable: !isBlocked, zones, multiplier };
    }
    return { cityId: null, cell: null, isServiceable: false, zones: [], multiplier: 1 };
  }

  /** City-specific fare rates for a vehicle, if configured. */
  async fareRule(cityId: string | null, vehicleKind: VehicleKind): Promise<CityFareRule | null> {
    if (!cityId) return null;
    const city = (await this.cities()).find((c) => c.city.id === cityId);
    return city?.city.fareRules.find((r) => r.vehicleKind === vehicleKind) ?? null;
  }

  /** Public service-area payload for the apps (cells + zones). */
  async serviceArea(cityId: string): Promise<{ id: string; name: string; resolution: number; cells: string[]; zones: Pick<Zone, 'id' | 'name' | 'kind' | 'cells' | 'surgeMultiplier' | 'color'>[] } | null> {
    const found = (await this.cities()).find((c) => c.city.id === cityId);
    if (!found) return null;
    const { city } = found;
    return {
      id: city.id,
      name: city.name,
      resolution: city.h3Resolution,
      cells: city.serviceCells,
      zones: city.zones.map(({ id, name, kind, cells, surgeMultiplier, color }) => ({ id, name, kind, cells, surgeMultiplier, color })),
    };
  }

  async activeCities(): Promise<Pick<City, 'id' | 'name' | 'state' | 'centerLat' | 'centerLng' | 'h3Resolution'>[]> {
    return (await this.cities()).map(({ city: { id, name, state, centerLat, centerLng, h3Resolution } }) => ({ id, name, state, centerLat, centerLng, h3Resolution }));
  }
}
