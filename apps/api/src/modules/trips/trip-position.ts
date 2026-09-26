import { UnprocessableEntityException } from '@nestjs/common';

import { haversineMeters } from '../fares/fare-engine.js';

export type TripStop = 'pickup' | 'drop';

/** Reasons the driver app offers (any 3–200 character text is accepted). */
export const FAR_REASONS = {
  pickup: ['Customer asked to meet here', 'Road blocked / no entry', 'Pickup pin is wrong', 'GPS is not accurate'],
  drop: ['Customer asked to stop here', 'Road blocked / no entry', 'Drop pin is wrong', 'GPS is not accurate'],
} as const;

export interface PositionCheck {
  /** Metres from the stop, or null when the driver's position is unknown (then nothing is enforced). */
  distanceM: number | null;
  farReason: string | null;
}

/**
 * Checks the driver is near the pickup (Arrived) or the drop (End ride / Complete delivery). Outside [radiusM]
 * without a reason → 422 `TOO_FAR` with the distance, so the app can ask for one; with a reason it goes through and
 * the reason is stored on the trip for admins.
 */
export function checkNearStop(params: {
  stop: TripStop;
  at: { lat: number; lng: number } | null;
  target: { lat: number; lng: number };
  radiusM: number;
  farReason?: string;
}): PositionCheck {
  if (!params.at) return { distanceM: null, farReason: params.farReason?.trim() || null };
  const distanceM = Math.round(haversineMeters(params.at, params.target));
  const reason = params.farReason?.trim() || null;
  if (distanceM <= params.radiusM) return { distanceM, farReason: null };
  if (!reason) {
    const away = distanceM >= 1000 ? `${(distanceM / 1000).toFixed(1)} km` : `${distanceM} m`;
    throw new UnprocessableEntityException({
      code: 'TOO_FAR',
      message: `You're ${away} from the ${params.stop === 'pickup' ? 'pickup' : 'drop'} point`,
      details: { stop: params.stop, distanceM, radiusM: params.radiusM, reasons: FAR_REASONS[params.stop] },
    });
  }
  return { distanceM, farReason: reason };
}
