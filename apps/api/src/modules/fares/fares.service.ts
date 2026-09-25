import { Injectable } from '@nestjs/common';

import { TripKind, VehicleKind } from '../../generated/prisma/enums.js';
import { GeoService } from '../geo/geo.service.js';
import { MapsService } from '../maps/maps.service.js';
import { FareQuote, GeoPoint, quoteFare } from './fare-engine.js';
import { FARE_RULES } from './fare-rules.js';

/** Quotes vehicles for a route. Distance comes from Google Routes when configured (cached), else haversine. */
@Injectable()
export class FaresService {
  constructor(
    private readonly maps: MapsService,
    private readonly geo: GeoService,
  ) {}

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

  async quoteOne(params: { pickup: GeoPoint; drop: GeoPoint; vehicleKind: VehicleKind }): Promise<FareQuote> {
    const route = await this.maps.estimate({ from: params.pickup, to: params.drop, vehicleKind: params.vehicleKind });
    const here = await this.geo.locate(params.pickup);
    const rule = (await this.geo.fareRule(here.cityId, params.vehicleKind)) ?? undefined;
    return quoteFare({ vehicleKind: params.vehicleKind, route, multiplier: here.multiplier, rule });
  }
}
