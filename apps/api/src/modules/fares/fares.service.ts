import { Injectable } from '@nestjs/common';

import { PrismaService } from '../../core/prisma/prisma.service.js';
import { TripKind, VehicleKind } from '../../generated/prisma/enums.js';
import { TripDriversService } from '../drivers/trip-drivers.service.js';
import { womenAmong } from '../drivers/women-drivers.js';
import { GeoService } from '../geo/geo.service.js';
import { EtaService, etasByMode } from '../maps/eta.service.js';
import { MapsService } from '../maps/maps.service.js';
import type { Settings } from '../settings/settings.defaults.js';
import { SettingsService } from '../settings/settings.service.js';
import { FareQuote, GeoPoint, quoteFare, type RouteEstimate } from './fare-engine.js';
import { FARE_RULES } from './fare-rules.js';

/** A quote on the vehicle list, with how soon the nearest free driver of that vehicle can reach the pickup. */
export interface QuoteWithEta extends FareQuote {
  /** Road minutes from the nearest free driver; null = nobody within the maximum search radius right now. */
  readonly pickupEtaMin: number | null;
}

/** The waiting terms from the admin settings. */
export const waitingSettings = (s: Pick<Settings, 'freeWaitMin' | 'waitMaxCharge'>): { freeMin: number; maxCharge: number } => ({
  freeMin: s.freeWaitMin,
  maxCharge: s.waitMaxCharge,
});

/** Nearest drivers (by straight line) whose road ETA is measured per vehicle; the fastest of them wins. */
const ETA_SAMPLE = 3;

/** Quotes vehicles for a route. Distance comes from Google Routes when configured (cached), else haversine. */
@Injectable()
export class FaresService {
  constructor(
    private readonly maps: MapsService,
    private readonly geo: GeoService,
    private readonly drivers: TripDriversService,
    private readonly eta: EtaService,
    private readonly settings: SettingsService,
    private readonly prisma: PrismaService,
  ) {}

  /**
   * Adds each vehicle's pickup ETA (P-10 "3 min away", "Drop 9:24 PM", Fastest). [womenOnly]: Butterfly "only".
   * Every vehicle's nearest drivers are measured together: one [EtaService.minutesMany] (so at most one Route Matrix
   * call) per travel mode, which is one for all vehicles today (all DRIVE).
   */
  async withPickupEta(quotes: readonly FareQuote[], pickup: GeoPoint, opts: { womenOnly: boolean }): Promise<QuoteWithEta[]> {
    const s = await this.settings.all();
    const radiusKm = Math.max(s.searchRadiusKm, s.maxSearchRadiusKm);
    const nearestPer = await Promise.all(
      quotes.map(async (q) => {
        // Bike drivers count for a goods bike (they take parcels too).
        let drivers = await this.drivers.nearby({ kind: q.vehicleKind, ...pickup, radiusKm, limit: ETA_SAMPLE * 2 });
        if (opts.womenOnly) {
          const women = await womenAmong(this.prisma, drivers.map((d) => d.driverId));
          drivers = drivers.filter((d) => women.has(d.driverId));
        }
        return [...drivers].sort((a, b) => a.distanceKm - b.distanceKm).slice(0, ETA_SAMPLE);
      }),
    );
    const etas = await etasByMode(
      quotes.flatMap((q, i) => nearestPer[i].map((d) => ({ at: d, vehicleKind: q.vehicleKind }))),
      (froms, vehicleKind) => this.eta.minutesMany({ froms, to: pickup, vehicleKind, useRoad: s.useRoadEta }),
    );
    let next = 0;
    return quotes.map((q, i): QuoteWithEta => {
      const mine = etas.slice(next, (next += nearestPer[i].length));
      return { ...q, pickupEtaMin: mine.length === 0 ? null : Math.min(...mine) };
    });
  }

  async quoteAll(params: { pickup: GeoPoint; drop: GeoPoint; kind: TripKind }): Promise<FareQuote[]> {
    const wantGoods = params.kind === TripKind.PARCEL;
    const route = await this.maps.estimate({ from: params.pickup, to: params.drop, vehicleKind: FaresService.routeVehicle(wantGoods) });
    const here = await this.geo.locate(params.pickup);
    const s = await this.settings.all();
    const kinds = (Object.keys(FARE_RULES) as VehicleKind[]).filter((k) => FARE_RULES[k].isGoods === wantGoods);
    return Promise.all(
      kinds.map(async (vehicleKind) => {
        const rule = (await this.geo.fareRule(here.cityId, vehicleKind)) ?? undefined;
        return quoteFare({ vehicleKind, route, multiplier: here.multiplier, maxMultiplier: s.maxMultiplier, rule, waiting: waitingSettings(s) });
      }),
    );
  }

  /** [vehicleKind] on a route already measured (e.g. a booked trip's), at the pickup's current rates. */
  async quoteOnRoute(params: { pickup: GeoPoint; route: RouteEstimate; vehicleKind: VehicleKind }): Promise<FareQuote> {
    const here = await this.geo.locate(params.pickup);
    const rule = (await this.geo.fareRule(here.cityId, params.vehicleKind)) ?? undefined;
    const s = await this.settings.all();
    return quoteFare({ vehicleKind: params.vehicleKind, route: params.route, multiplier: here.multiplier, maxMultiplier: s.maxMultiplier, rule, waiting: waitingSettings(s) });
  }

  /**
   * The booked vehicle's fare, on the same route [quoteAll] priced for P-10 (the car / three-wheeler route), so the
   * booked fare is the one the passenger saw (and a bike booking doesn't make an extra two-wheeler Routes call).
   */
  async quoteOne(params: { pickup: GeoPoint; drop: GeoPoint; vehicleKind: VehicleKind }): Promise<FareQuote> {
    const route = await this.maps.estimate({ from: params.pickup, to: params.drop, vehicleKind: FaresService.routeVehicle(FARE_RULES[params.vehicleKind].isGoods) });
    const here = await this.geo.locate(params.pickup);
    const rule = (await this.geo.fareRule(here.cityId, params.vehicleKind)) ?? undefined;
    const s = await this.settings.all();
    return quoteFare({ vehicleKind: params.vehicleKind, route, multiplier: here.multiplier, maxMultiplier: s.maxMultiplier, rule, waiting: waitingSettings(s) });
  }

  /** One route prices every vehicle of a kind: rides on the car route, goods on the three-wheeler route. */
  static routeVehicle(isGoods: boolean): VehicleKind {
    return isGoods ? VehicleKind.THREE_WHEELER : VehicleKind.CAB;
  }

  /** Waiting-charge rate per started minute for [vehicleKind] at [at] (the city's rule, else the built-in one). */
  async waitPerMin(at: GeoPoint, vehicleKind: VehicleKind): Promise<number> {
    const here = await this.geo.locate(at);
    const rule = await this.geo.fareRule(here.cityId, vehicleKind);
    return rule?.waitPerMin ?? FARE_RULES[vehicleKind].waitPerMin;
  }
}
