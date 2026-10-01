import { TripKind, TripStatus } from '../../generated/prisma/enums.js';

/**
 * Allowed status changes for rides and parcels. Back to SEARCHING from DRIVER_ASSIGNED / DRIVER_ARRIVED = the driver
 * dropped the trip before pickup and dispatch looks for another ([canReassign]).
 */
const RIDE: Readonly<Partial<Record<TripStatus, readonly TripStatus[]>>> = {
  SCHEDULED: [TripStatus.SEARCHING, TripStatus.CANCELLED],
  SEARCHING: [TripStatus.DRIVER_ASSIGNED, TripStatus.NO_DRIVERS, TripStatus.CANCELLED],
  NO_DRIVERS: [TripStatus.SEARCHING, TripStatus.CANCELLED],
  DRIVER_ASSIGNED: [TripStatus.DRIVER_ARRIVED, TripStatus.SEARCHING, TripStatus.CANCELLED],
  DRIVER_ARRIVED: [TripStatus.IN_PROGRESS, TripStatus.SEARCHING, TripStatus.CANCELLED],
  IN_PROGRESS: [TripStatus.COMPLETED],
} as const;

const PARCEL: Readonly<Partial<Record<TripStatus, readonly TripStatus[]>>> = {
  SEARCHING: [TripStatus.DRIVER_ASSIGNED, TripStatus.NO_DRIVERS, TripStatus.CANCELLED],
  NO_DRIVERS: [TripStatus.SEARCHING, TripStatus.CANCELLED],
  DRIVER_ASSIGNED: [TripStatus.DRIVER_ARRIVED, TripStatus.SEARCHING, TripStatus.CANCELLED],
  DRIVER_ARRIVED: [TripStatus.PICKED_UP, TripStatus.SEARCHING, TripStatus.CANCELLED],
  PICKED_UP: [TripStatus.DELIVERED],
} as const;

/** True if a trip of [kind] may move from [from] to [to]. */
export function canTransition(params: { kind: TripKind; from: TripStatus; to: TripStatus }): boolean {
  const table = params.kind === TripKind.PARCEL ? PARCEL : RIDE;
  return table[params.from]?.includes(params.to) ?? false;
}

/** Finished trips can no longer change. */
export function isFinished(status: TripStatus): boolean {
  return status === TripStatus.COMPLETED || status === TripStatus.DELIVERED || status === TripStatus.CANCELLED;
}

/** A driver dropping the trip in [status] sends it back to searching (before pickup only). */
export function canReassign(params: { kind: TripKind; status: TripStatus }): boolean {
  return (
    (params.status === TripStatus.DRIVER_ASSIGNED || params.status === TripStatus.DRIVER_ARRIVED) &&
    canTransition({ kind: params.kind, from: params.status, to: TripStatus.SEARCHING })
  );
}
