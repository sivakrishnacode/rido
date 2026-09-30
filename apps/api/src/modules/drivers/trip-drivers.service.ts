import { Injectable } from '@nestjs/common';

import { PrismaService } from '../../core/prisma/prisma.service.js';
import type { VehicleKind } from '../../generated/prisma/enums.js';
import { DriverLocationService, type NearbyDriver } from './driver-location.service.js';
import { driverKindsFor, parcelsOffAmong } from './parcel-bikes.js';

/** A free driver who can take the trip, with their own vehicle ([kind], for the ETA and the fare they take it at). */
export interface CapableDriver extends NearbyDriver {
  readonly kind: VehicleKind;
}

/**
 * Who can take a trip booked as a vehicle: that vehicle's free drivers, plus bike drivers for a goods-bike parcel
 * (parcel-bikes.ts) unless they turned parcels off. Used by dispatch, the vehicle list's pickup ETAs and "Book any".
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
    const off = await parcelsOffAmong(this.prisma, extra.map((d) => d.driverId));
    return [...own, ...extra.filter((d) => !off.has(d.driverId))].sort((a, b) => a.ring - b.ring || a.distanceKm - b.distanceKm);
  }
}
