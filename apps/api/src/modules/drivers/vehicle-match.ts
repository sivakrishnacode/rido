import type { PrismaService } from '../../core/prisma/prisma.service.js';
import { TripKind, VehicleKind } from '../../generated/prisma/enums.js';

/**
 * Which drivers can take a trip booked as a vehicle kind.
 * - Parcel on bike (like Rapido's "Parcel on Scooty"): bike and scooter drivers also carry goods-bike parcels, unless
 *   they turned it off in their booking preferences (`parcels: false`). A goods-bike driver never gets passengers.
 * - Scooters (SCOOTY) also take Bike rides (a two-wheeler either way, at the Bike fare); bikes don't take Scooty rides.
 * - Auto Priority is a booking tier, not a vehicle: auto drivers serve it at its higher fare, and it is offered first.
 * Cab tiers (Mini, Sedan, SUV) are served only by their own vehicles.
 */

/** Two-wheelers that can carry goods-bike parcels too. */
export const PARCEL_TWO_WHEELERS: readonly VehicleKind[] = [VehicleKind.BIKE, VehicleKind.SCOOTY];

/** Vehicle kinds a driver can register with (every kind except booking tiers). */
export const DRIVER_VEHICLE_KINDS: readonly VehicleKind[] = Object.values(VehicleKind).filter((k) => k !== VehicleKind.AUTO_PRIORITY);

/** The driver vehicles that can take a trip booked as [kind]: its own drivers first, then the others listed above. */
export function driverKindsFor(kind: VehicleKind): VehicleKind[] {
  switch (kind) {
    case VehicleKind.GOODS_BIKE:
      return [VehicleKind.GOODS_BIKE, ...PARCEL_TWO_WHEELERS];
    case VehicleKind.BIKE:
      return [VehicleKind.BIKE, VehicleKind.SCOOTY];
    case VehicleKind.AUTO_PRIORITY:
      return [VehicleKind.AUTO];
    default:
      return [kind];
  }
}

/** The vehicle a [driverKind] driver takes a [tripKind] trip as: a bike or scooter on a parcel is a goods bike. */
export function tripVehicleFor(driverKind: VehicleKind, tripKind: TripKind): VehicleKind {
  return PARCEL_TWO_WHEELERS.includes(driverKind) && tripKind === TripKind.PARCEL ? VehicleKind.GOODS_BIKE : driverKind;
}

/** Trips offered first in a batch (Auto Priority). */
export function isPriority(kind: VehicleKind): boolean {
  return kind === VehicleKind.AUTO_PRIORITY;
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
