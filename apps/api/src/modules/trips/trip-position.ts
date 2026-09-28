import { UnprocessableEntityException } from '@nestjs/common';

import { haversineMeters } from '../fares/fare-engine.js';

export type TripStop = 'pickup' | 'drop';

/** Reasons the driver app offers (any 3–200 character text is accepted). */
export const FAR_REASONS = {
  pickup: ['Customer asked to meet here', 'Road blocked / no entry', 'Pickup pin is wrong', 'GPS is not accurate'],
  drop: ['Customer asked to stop here', 'Road blocked / no entry', 'Drop pin is wrong', 'GPS is not accurate'],
} as const;

/** A server fix newer than this is trusted over the position the app sends with Arrived / End. */
export const SERVER_FIX_MAX_AGE_MS = 30_000;

type LatLng = { lat: number; lng: number };

/**
 * Which position the Arrived / End check uses. The app's GPS stream reaches the server continuously, so a fresh
 * server fix wins over the coordinates in the request body (which a modified app could fake). The body is used only
 * when the server has no fresh fix (stream down); failing both, a stale server fix, else unknown.
 */
export function positionForCheck(params: {
  server: (LatLng & { at: number | null }) | null;
  sent: Partial<LatLng>;
  now: number;
  maxAgeMs?: number;
}): LatLng | null {
  const { server, sent } = params;
  const isFresh = !!server && server.at !== null && params.now - server.at <= (params.maxAgeMs ?? SERVER_FIX_MAX_AGE_MS);
  if (server && isFresh) return { lat: server.lat, lng: server.lng };
  if (sent.lat !== undefined && sent.lng !== undefined) return { lat: sent.lat, lng: sent.lng };
  return server && { lat: server.lat, lng: server.lng };
}

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
