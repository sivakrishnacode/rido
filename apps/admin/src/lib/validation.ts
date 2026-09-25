import type { Settings } from "./types";

export type SettingsErrors = Partial<Record<keyof Settings, string>>;

function inRange(v: number, min: number, max: number, isInteger = false): boolean {
  return Number.isFinite(v) && v >= min && v <= max && (!isInteger || Number.isInteger(v));
}

/** Client + server validation for PUT /admin/settings (keys from settings.defaults.ts). */
export function validateSettings(s: Settings): SettingsErrors {
  const e: SettingsErrors = {};
  if (!inRange(s.maxMultiplier, 1, 1.5)) e.maxMultiplier = "Maximum multiplier must be 1.0–1.5";
  if (!inRange(s.currentMultiplier, 1, 1.5)) e.currentMultiplier = "Current multiplier must be 1.0–1.5";
  else if (inRange(s.maxMultiplier, 1, 1.5) && s.currentMultiplier > s.maxMultiplier) {
    e.currentMultiplier = "Current multiplier can't exceed the maximum";
  }
  if (!inRange(s.searchRadiusKm, 0.5, 30)) e.searchRadiusKm = "Search radius must be 0.5–30 km";
  if (!inRange(s.offerSeconds, 5, 120, true)) e.offerSeconds = "Offer time must be 5–120 whole seconds";
  if (!inRange(s.maxCandidates, 1, 20, true)) e.maxCandidates = "Drivers per booking must be 1–20";
  if (!inRange(s.trialDays, 0, 365, true)) e.trialDays = "Trial must be 0–365 days";
  if (!inRange(s.graceDays, 0, 30, true)) e.graceDays = "Grace period must be 0–30 days";
  if (!inRange(s.batchWindowMs, 0, 10_000, true)) e.batchWindowMs = "Batch window must be 0–10,000 ms";
  if (typeof s.useRoadEta !== "boolean") e.useRoadEta = "Road ETA must be on or off";
  if (!/^\+?[\d\s-]{8,20}$/.test(s.supportPhone.trim())) e.supportPhone = "Enter a phone number like +91 422 000 0000";
  return e;
}

/** H3 resolution 8 hexagon ≈ 0.737 km² (average area). */
export const KM2_PER_CELL: Record<number, number> = { 7: 5.161, 8: 0.737, 9: 0.105 };

export function cellsToKm2(count: number, resolution = 8): number {
  return count * (KM2_PER_CELL[resolution] ?? 0.737);
}

const EPS = 1e-9;
const floorRupee = (v: number): number => Math.floor(v + EPS);

export interface FarePreview {
  readonly base: number;
  readonly distanceCharge: number;
  readonly timeCharge: number;
  readonly minFareTopUp: number;
  readonly subtotal: number;
  readonly multiplier: number;
  readonly peakCharge: number;
  readonly total: number;
}

/**
 * Mirrors apps/api/src/modules/fares/fare-engine.ts: each line floored to the rupee,
 * subtotal = max(minFare, base + perKm×km + perMin×min), total = floor(subtotal × multiplier), multiplier 1.0–1.5.
 */
export function previewFare(
  rule: { base: number; perKm: number; perMin: number; minFare: number },
  km: number,
  minutes: number,
  multiplier = 1,
): FarePreview {
  const m = Math.min(1.5, Math.max(1, Number.isFinite(multiplier) ? multiplier : 1));
  const distanceCharge = floorRupee(rule.perKm * Math.max(0, km));
  const timeCharge = floorRupee(rule.perMin * Math.max(0, minutes));
  const raw = rule.base + distanceCharge + timeCharge;
  const minFareTopUp = Math.max(0, rule.minFare - raw);
  const subtotal = raw + minFareTopUp;
  const total = floorRupee(subtotal * m);
  return { base: rule.base, distanceCharge, timeCharge, minFareTopUp, subtotal, multiplier: m, peakCharge: total - subtotal, total };
}
