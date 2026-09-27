import { Injectable } from '@nestjs/common';

import { PrismaService } from '../../core/prisma/prisma.service.js';
import { TripKind, VehicleKind } from '../../generated/prisma/enums.js';
import { DriverLocationService } from '../drivers/driver-location.service.js';
import { womenAmong } from '../drivers/women-drivers.js';
import { GeoService } from '../geo/geo.service.js';
import { EtaService } from '../maps/eta.service.js';
import { MapsService } from '../maps/maps.service.js';
import { SettingsService } from '../settings/settings.service.js';
import { FareQuote, GeoPoint, quoteFare, type RouteEstimate } from './fare-engine.js';
import { FARE_RULES } from './fare-rules.js';

/** A quote on the vehicle list, with how soon the nearest free driver of that vehicle can reach the pickup. */
export interface QuoteWithEta extends FareQuote {
  /** Road minutes from the nearest free driver; null = nobody within the maximum search radius right now. */
  readonly pickupEtaMin: number | null;
}

/** Nearest drivers (by straight line) whose road ETA is measured per vehicle; the fastest of them wins. */
const ETA_SAMPLE = 3;

/** Quotes vehicles for a route. Distance comes from Google Routes when configured (cached), else haversine. */
@Injectable()
export class FaresService {
  constructor(
    private readonly maps: MapsService,
    private readonly geo: GeoService,
    private readonly location: DriverLocationService,
    private readonly eta: EtaService,
    private readonly settings: SettingsService,
    private readonly prisma: PrismaService,
  ) {}

  /** Adds each vehicle's pickup ETA (P-10 "3 min away", "Drop 9:24 PM", Fastest). [womenOnly]: Butterfly "only". */
  async withPickupEta(quotes: readonly FareQuote[], pickup: GeoPoint, opts: { womenOnly: boolean }): Promise<QuoteWithEta[]> {
    const s = await this.settings.all();
    const radiusKm = Math.max(s.searchRadiusKm, s.maxSearchRadiusKm);
    return Promise.all(
      quotes.map(async (q): Promise<QuoteWithEta> => {
        let drivers = await this.location.nearby({ kind: q.vehicleKind, ...pickup, radiusKm, limit: ETA_SAMPLE * 2 });
        if (opts.womenOnly) {
          const women = await womenAmong(this.prisma, drivers.map((d) => d.driverId));
          drivers = drivers.filter((d) => women.has(d.driverId));
        }
        const nearest = [...drivers].sort((a, b) => a.distanceKm - b.distanceKm).slice(0, ETA_SAMPLE);
        if (nearest.length === 0) return { ...q, pickupEtaMin: null };
        const etas = await Promise.all(
          nearest.map((d) => this.eta.minutes({ from: d, to: pickup, vehicleKind: q.vehicleKind, useRoad: s.useRoadEta })),
        );
        return { ...q, pickupEtaMin: Math.min(...etas) };
      }),
    );
  }

  async quoteAll(params: { pickup: GeoPoint; drop: GeoPoint; kind: TripKind }): Promise<FareQuote[]> {
    const wantGoods = params.kind === TripKind.PARCEL;
    const route = await this.maps.estimate({ from: params.pickup, to: params.drop, vehicleKind: wantGoods ? VehicleKind.THREE_WHEELER : VehicleKind.CAB });
    const here = await this.geo.locate(params.pickup);
    const kinds = (Object.keys(FARE_RULES) as VehicleKind[]).filter((k) => FARE_RULES[k].isGoods === wantGoods);
    return Promise.all(
      kinds.map(async (vehicleKind) => {
        const rule = (await this.geo.fareRule(here.cityId, vehicleKind)) ?? undefined;
        return quoteFare({ vehicleKind, route, multiplier: here.multiplier, rule });
      }),
    );
  }

  /** [vehicleKind] on a route already measured (e.g. a booked trip's), at the pickup's current rates. */
  async quoteOnRoute(params: { pickup: GeoPoint; route: RouteEstimate; vehicleKind: VehicleKind }): Promise<FareQuote> {
    const here = await this.geo.locate(params.pickup);
    const rule = (await this.geo.fareRule(here.cityId, params.vehicleKind)) ?? undefined;
    return quoteFare({ vehicleKind: params.vehicleKind, route: params.route, multiplier: here.multiplier, rule });
  }

  async quoteOne(params: { pickup: GeoPoint; drop: GeoPoint; vehicleKind: VehicleKind }): Promise<FareQuote> {
    const route = await this.maps.estimate({ from: params.pickup, to: params.drop, vehicleKind: params.vehicleKind });
    const here = await this.geo.locate(params.pickup);
    const rule = (await this.geo.fareRule(here.cityId, params.vehicleKind)) ?? undefined;
    return quoteFare({ vehicleKind: params.vehicleKind, route, multiplier: here.multiplier, rule });
  }
}
