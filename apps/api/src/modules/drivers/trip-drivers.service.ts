import { Injectable } from '@nestjs/common';

import { PrismaService } from '../../core/prisma/prisma.service.js';
import { VehicleKind } from '../../generated/prisma/enums.js';
import { DriverLocationService, type NearbyDriver } from './driver-location.service.js';
import { driverKindsFor, parcelsOffAmong } from './vehicle-match.js';

/** A free driver who can take the trip, with their own vehicle ([kind], for the ETA and the fare they take it at). */
export interface CapableDriver extends NearbyDriver {
  readonly kind: VehicleKind;
}

/**
 * Who can take a trip booked as a vehicle: that vehicle's free drivers, plus the others vehicle-match.ts allows (bikes
 * and scooters for a goods-bike parcel unless they turned parcels off, scooters for a Bike ride, autos for Auto
 * Priority). Used by dispatch, the vehicle list's pickup ETAs and "Book any".
 */
@Injectable()
export class TripDriversService {
  constructor(
    private readonly location: DriverLocationService,
    private readonly prisma: PrismaService,
  ) {}

  /** Nearest first (hexagon ring, then straight line), like [DriverLocationService.nearby]. */
  async nearby(params: { kind: VehicleKind; lat: number; lng: number; radiusKm: number; limit: number }): Promise<CapableDriver[]> {
    const perKind = await Promise.all(
      driverKindsFor(params.kind).map(async (kind) => (await this.location.nearby({ ...params, kind })).map((d) => ({ ...d, kind }))),
    );
    const [own, ...others] = perKind;
    const extra = others.flat();
    if (extra.length === 0) return own;
    // Parcels too is a booking preference: two-wheelers that turned it off don't get goods-bike parcels.
    const off = params.kind === VehicleKind.GOODS_BIKE ? await parcelsOffAmong(this.prisma, extra.map((d) => d.driverId)) : new Set<string>();
    return [...own, ...extra.filter((d) => !off.has(d.driverId))].sort((a, b) => a.ring - b.ring || a.distanceKm - b.distanceKm);
  }
}
