import type { Settings } from "./types";

export type SettingValue = number | boolean | string;
export type SettingsInput = Partial<Record<keyof Settings, SettingValue>> & Record<string, SettingValue>;
export type SettingsErrors = Partial<Record<string, string>>;

function inRange(v: unknown, min: number, max: number, isInteger = false): boolean {
  return typeof v === "number" && Number.isFinite(v) && v >= min && v <= max && (!isInteger || Number.isInteger(v));
}

/** Rules for the known settings keys (apps/api/src/modules/settings/settings.defaults.ts). */
const RULES: Record<string, (v: SettingValue) => string | null> = {
  maxMultiplier: (v) => (inRange(v, 1, 1.5) ? null : "Maximum multiplier must be 1.0–1.5"),
  currentMultiplier: (v) => (inRange(v, 1, 1.5) ? null : "Current multiplier must be 1.0–1.5"),
  searchRadiusKm: (v) => (inRange(v, 0.5, 30) ? null : "Search radius must be 0.5–30 km"),
  offerSeconds: (v) => (inRange(v, 5, 120, true) ? null : "Offer time must be 5–120 whole seconds"),
  maxCandidates: (v) => (inRange(v, 1, 20, true) ? null : "Drivers per booking must be 1–20"),
  arrivalRadiusM: (v) => (inRange(v, 50, 2000, true) ? null : "Arrived radius must be 50–2,000 whole metres"),
  dropRadiusM: (v) => (inRange(v, 50, 5000, true) ? null : "End-trip radius must be 50–5,000 whole metres"),
  trialDays: (v) => (inRange(v, 0, 365, true) ? null : "Trial must be 0–365 days"),
  graceDays: (v) => (inRange(v, 0, 30, true) ? null : "Grace period must be 0–30 days"),
  batchWindowMs: (v) => (inRange(v, 0, 10_000, true) ? null : "Batch window must be 0–10,000 ms"),
  surgeSensitivity: (v) => (inRange(v, 0, 1) ? null : "Sensitivity must be 0–1 (e.g. 0.1)"),
  demandWindowMin: (v) => (inRange(v, 1, 120, true) ? null : "Demand window must be 1–120 whole minutes"),
  surgeMinRequests: (v) => (inRange(v, 0, 1000, true) ? null : "Minimum requests must be a whole number 0–1,000"),
  historicalEtaMinTrips: (v) => (inRange(v, 0, 10_000, true) ? null : "Minimum trips must be a whole number (0 = off)"),
  useRoadEta: (v) => (typeof v === "boolean" ? null : "Road ETA must be on or off"),
  dynamicSurgeEnabled: (v) => (typeof v === "boolean" ? null : "Dynamic surge must be on or off"),
  supportPhone: (v) => (typeof v === "string" && /^\+?[\d\s-]{8,20}$/.test(v.trim()) ? null : "Enter a phone number like +91 422 000 0000"),
};

/** Client + server validation for PUT /admin/settings. Only the keys present are checked; unknown numbers must be finite. */
export function validateSettings(s: SettingsInput): SettingsErrors {
  const e: SettingsErrors = {};
  for (const [key, value] of Object.entries(s)) {
    const rule = RULES[key];
    const error = rule ? rule(value) : typeof value === "number" && !Number.isFinite(value) ? "Enter a number" : null;
    if (error) e[key] = error;
  }
  const cur = s.currentMultiplier;
  const max = s.maxMultiplier;
  if (!e.currentMultiplier && !e.maxMultiplier && typeof cur === "number" && typeof max === "number" && cur > max) {
    e.currentMultiplier = "Current multiplier can't exceed the maximum";
  }
  return e;
}

/** multiplier = 1 + sensitivity × (ratio − 1), capped, rounded down to 0.05 (apps/api/src/modules/geo/surge.ts). */
export function surgeExample(ratio: number, sensitivity: number, maxMultiplier: number): number {
  if (!(ratio > 1)) return 1;
  const raw = Math.min(maxMultiplier, 1 + sensitivity * (ratio - 1));
  return Math.floor(raw * 20 + 1e-9) / 20;
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
