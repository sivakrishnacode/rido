import type { PrismaService } from '../../core/prisma/prisma.service.js';
import { TripKind, VehicleKind } from '../../generated/prisma/enums.js';

/**
 * Parcel on bike (like Rapido's "Parcel on Scooty"): bike drivers also carry goods-bike parcels, unless they turned
 * it off in their booking preferences (`parcels: false`). A goods-bike driver never gets passengers.
 */

/** The driver vehicles that can take a trip booked as [kind]: its own drivers, plus bikes for a goods bike. */
export function driverKindsFor(kind: VehicleKind): VehicleKind[] {
  return kind === VehicleKind.GOODS_BIKE ? [VehicleKind.GOODS_BIKE, VehicleKind.BIKE] : [kind];
}

/** The vehicle a [driverKind] driver takes a [tripKind] trip as: a bike on a parcel is a goods bike. */
export function tripVehicleFor(driverKind: VehicleKind, tripKind: TripKind): VehicleKind {
  return driverKind === VehicleKind.BIKE && tripKind === TripKind.PARCEL ? VehicleKind.GOODS_BIKE : driverKind;
}

/** The ids among [driverIds] who turned parcels off (no preferences = parcels on). */
export async function parcelsOffAmong(prisma: PrismaService, driverIds: readonly string[]): Promise<Set<string>> {
  if (driverIds.length === 0) return new Set();
  const rows = await prisma.driver.findMany({
    where: { id: { in: [...driverIds] }, bookingPrefs: { path: ['parcels'], equals: false } },
    select: { id: true },
  });
  return new Set(rows.map((r) => r.id));
}
