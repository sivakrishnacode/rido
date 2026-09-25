import type { PlanPeriod, VehicleKind } from '../../generated/prisma/enums.js';

/** Driver plan prices in rupees, GST-inclusive (docs/BUSINESS_MODEL.md §4.1). */
export const PLAN_PRICES: Readonly<Record<VehicleKind, Readonly<Record<PlanPeriod, number>>>> = {
  BIKE: { DAILY: 79, WEEKLY: 449, MONTHLY: 1499 },
  AUTO: { DAILY: 35, WEEKLY: 199, MONTHLY: 749 },
  CAB: { DAILY: 49, WEEKLY: 279, MONTHLY: 999 },
  GOODS_BIKE: { DAILY: 79, WEEKLY: 449, MONTHLY: 1499 },
  THREE_WHEELER: { DAILY: 99, WEEKLY: 549, MONTHLY: 1999 },
  MINI_TRUCK: { DAILY: 149, WEEKLY: 799, MONTHLY: 2999 },
  PICKUP: { DAILY: 199, WEEKLY: 1099, MONTHLY: 3999 },
  TRUCK: { DAILY: 199, WEEKLY: 1099, MONTHLY: 3999 },
} as const;

/** Length of each period in days. */
export const PERIOD_DAYS: Readonly<Record<PlanPeriod, number>> = { DAILY: 1, WEEKLY: 7, MONTHLY: 30 } as const;

/** Days a lapsed plan can still go online. */
export const GRACE_DAYS = 2;

/** Free trial length for new drivers. */
export const TRIAL_DAYS = 30;
