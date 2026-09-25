import type { VehicleKind } from '../../generated/prisma/enums.js';

/** Per-vehicle rates. fare = max(minFare, base + perKm × km + perMin × min) × multiplier. */
export interface FareRule {
  readonly base: number;
  readonly perKm: number;
  readonly perMin: number;
  readonly minFare: number;
  /** Minutes until the nearest driver usually arrives (display only). */
  readonly etaMin: number;
  readonly isGoods: boolean;
  /** Seats (rides) or capacity in kg (goods). */
  readonly capacity: number;
}

/** Same rates as the apps (packages/rido_data/lib/src/seed.dart). */
export const FARE_RULES: Readonly<Record<VehicleKind, FareRule>> = {
  BIKE: { base: 12, perKm: 5, perMin: 0.15, minFare: 25, etaMin: 2, isGoods: false, capacity: 1 },
  AUTO: { base: 25, perKm: 9, perMin: 0.3, minFare: 35, etaMin: 4, isGoods: false, capacity: 3 },
  CAB: { base: 48, perKm: 15, perMin: 1.5, minFare: 90, etaMin: 6, isGoods: false, capacity: 4 },
  GOODS_BIKE: { base: 10, perKm: 5, perMin: 0.05, minFare: 30, etaMin: 3, isGoods: true, capacity: 10 },
  THREE_WHEELER: { base: 50, perKm: 15, perMin: 0.55, minFare: 120, etaMin: 6, isGoods: true, capacity: 500 },
  MINI_TRUCK: { base: 140, perKm: 35, perMin: 0.2, minFare: 300, etaMin: 9, isGoods: true, capacity: 750 },
  PICKUP: { base: 250, perKm: 45, perMin: 1, minFare: 500, etaMin: 12, isGoods: true, capacity: 1500 },
  TRUCK: { base: 500, perKm: 70, perMin: 1.5, minFare: 1000, etaMin: 15, isGoods: true, capacity: 4000 },
} as const;
