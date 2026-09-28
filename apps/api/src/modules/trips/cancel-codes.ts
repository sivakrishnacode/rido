import { CancelCode, CancelledBy } from '../../generated/prisma/enums.js';

/** The codes each side may send (SYSTEM codes are set by the server only; admins may use any). */
export const CANCEL_CODES_FOR: Readonly<Record<CancelledBy, readonly CancelCode[]>> = {
  PASSENGER: [
    CancelCode.CHANGED_MIND,
    CancelCode.DRIVER_TOO_FAR,
    CancelCode.DRIVER_ASKED_TO_CANCEL,
    CancelCode.WAIT_TOO_LONG,
    CancelCode.BOOKED_BY_MISTAKE,
    CancelCode.OTHER,
  ],
  DRIVER: [
    CancelCode.PASSENGER_NO_SHOW,
    CancelCode.PASSENGER_UNREACHABLE,
    CancelCode.PASSENGER_ASKED_TO_CANCEL,
    CancelCode.VEHICLE_ISSUE,
    CancelCode.TOO_FAR,
    CancelCode.BUTTERFLY_MISMATCH,
    CancelCode.OTHER,
  ],
  SYSTEM: [CancelCode.NO_DRIVERS, CancelCode.DRIVER_NOT_MOVING, CancelCode.STUCK, CancelCode.OTHER],
  ADMIN: Object.values(CancelCode),
};

/** Short labels (pushes, admin). The apps have their own copies in rido_data `CancelCode`. */
export const CANCEL_CODE_LABEL: Readonly<Record<CancelCode, string>> = {
  CHANGED_MIND: 'Changed my plan',
  DRIVER_TOO_FAR: 'Driver too far',
  DRIVER_ASKED_TO_CANCEL: 'Driver asked me to cancel',
  WAIT_TOO_LONG: 'Waited too long',
  BOOKED_BY_MISTAKE: 'Booked by mistake',
  PASSENGER_NO_SHOW: "Passenger didn't come",
  PASSENGER_UNREACHABLE: 'Passenger not reachable',
  PASSENGER_ASKED_TO_CANCEL: 'Passenger asked me to cancel',
  VEHICLE_ISSUE: 'Vehicle problem',
  TOO_FAR: 'Pickup is too far',
  BUTTERFLY_MISMATCH: 'Rider is not a woman',
  NO_DRIVERS: 'No drivers available',
  DRIVER_NOT_MOVING: 'Driver was not moving',
  STUCK: 'Trip ran far too long',
  OTHER: 'Other reason',
};

/** Reason texts older app versions send in `reason` (no code), by who sent them. */
const LEGACY_REASONS: Readonly<Record<string, CancelCode>> = {
  'Driver too far': CancelCode.DRIVER_TOO_FAR,
  'Changed my plan': CancelCode.CHANGED_MIND,
  'Booked by mistake': CancelCode.BOOKED_BY_MISTAKE,
  'Cancelled while searching': CancelCode.CHANGED_MIND,
  'Cancelled by sender': CancelCode.CHANGED_MIND,
  'Rider is not a woman': CancelCode.BUTTERFLY_MISMATCH,
  'Passenger not reachable': CancelCode.PASSENGER_UNREACHABLE,
  'Passenger asked me to cancel': CancelCode.PASSENGER_ASKED_TO_CANCEL,
  'Pickup is too far': CancelCode.TOO_FAR,
  'Vehicle problem': CancelCode.VEHICLE_ISSUE,
};

/**
 * The code and note to store for a cancel by [by]. A code this side may not use becomes OTHER; an old client's
 * `reason` alone is mapped to its code (and kept as the note).
 */
export function resolveCancel(params: { by: CancelledBy; code?: CancelCode; note?: string; reason?: string }): { code: CancelCode; note: string | null } {
  const note = (params.note ?? params.reason)?.trim() || null;
  const code = params.code ?? (params.reason ? LEGACY_REASONS[params.reason.trim()] : undefined) ?? CancelCode.OTHER;
  return { code: CANCEL_CODES_FOR[params.by].includes(code) ? code : CancelCode.OTHER, note };
}

/**
 * Counted against the driver in cancellation rates: their own cancels (except a no-show after the wait and a
 * Butterfly mismatch report) and the system taking a trip off a driver who wasn't moving.
 */
export function isDriverFault(by: CancelledBy, code: CancelCode): boolean {
  if (by === CancelledBy.DRIVER) return code !== CancelCode.PASSENGER_NO_SHOW && code !== CancelCode.BUTTERFLY_MISMATCH;
  return by === CancelledBy.SYSTEM && code === CancelCode.DRIVER_NOT_MOVING;
}
