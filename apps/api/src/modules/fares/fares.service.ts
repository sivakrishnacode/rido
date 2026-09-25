import { Injectable } from '@nestjs/common';

import { TripKind, VehicleKind } from '../../generated/prisma/enums.js';
import { estimateRoute, FareQuote, GeoPoint, quoteFare } from './fare-engine.js';
import { FARE_RULES } from './fare-rules.js';

/** Quotes every vehicle of a trip kind for a route. */
@Injectable()
export class FaresService {
  quoteAll(params: { pickup: GeoPoint; drop: GeoPoint; kind: TripKind }): FareQuote[] {
    const route = estimateRoute(params.pickup, params.drop);
    const wantGoods = params.kind === TripKind.PARCEL;
    return (Object.keys(FARE_RULES) as VehicleKind[])
      .filter((k) => FARE_RULES[k].isGoods === wantGoods)
      .map((vehicleKind) => quoteFare({ vehicleKind, route }));
  }

  quoteOne(params: { pickup: GeoPoint; drop: GeoPoint; vehicleKind: VehicleKind }): FareQuote {
    return quoteFare({ vehicleKind: params.vehicleKind, route: estimateRoute(params.pickup, params.drop) });
  }
}
