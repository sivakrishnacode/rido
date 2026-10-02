import { istDay } from '../drivers/driver-earnings.service.js';

/** Selfie-check attempts a driver gets per IST day (each one is a paid Didit face match). */
export const SELFIE_TRIES_PER_DAY = 5;

/**
 * Must the driver pass a selfie check before going online today? Only when the setting is on, Didit can match faces,
 * and the driver has a reference face (the live selfie of their approved identity check: drivers approved before
 * Didit, or in dev without it, have none and are never asked). Once a day, by the IST calendar.
 */
export function isSelfieCheckRequired(params: {
  isEnabled: boolean;
  isDiditEnabled: boolean;
  hasReferenceFace: boolean;
  checkedAt: Date | null;
  now: Date;
}): boolean {
  if (!params.isEnabled || !params.isDiditEnabled || !params.hasReferenceFace) return false;
  return !params.checkedAt || istDay(params.checkedAt) !== istDay(params.now);
}

/** Redis key counting today's attempts (IST day). */
export function selfieTriesKey(driverId: string, now: Date): string {
  return `driver:selfie-tries:${driverId}:${istDay(now)}`;
}
