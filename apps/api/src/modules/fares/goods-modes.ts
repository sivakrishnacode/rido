import { VehicleKind } from '../../generated/prisma/enums.js';
import type { OutstationTerms } from './ride-modes.js';

/**
 * Goods beyond a delivery in town: goods to another town (one way, by the km) and house shifting (a goods vehicle,
 * helpers, stairs, packing and extras, on a chosen day and time slot). Same rates as the apps
 * (packages/tamiltaxi_data/lib/src/goods_modes.dart); the shared cases live in
 * packages/tamiltaxi_data/test/fixtures/goods_mode_cases.json. No surge: the price is agreed up front.
 */

/** The goods vehicles that go to other towns and do house shifting (not the goods bike). */
export const GOODS_TRUCKS: readonly VehicleKind[] = [VehicleKind.THREE_WHEELER, VehicleKind.MINI_TRUCK, VehicleKind.PICKUP, VehicleKind.TRUCK];
export type GoodsTruck = 'THREE_WHEELER' | 'MINI_TRUCK' | 'PICKUP' | 'TRUCK';

export const isGoodsTruck = (k: VehicleKind): k is GoodsTruck => (GOODS_TRUCKS as readonly string[]).includes(k);

// ------------------------------------------------------------------------------------------- goods outstation

/** One way to another town: the route km (at least [minKm]) at [perKm]; the driver drives back empty. */
export type GoodsOutstationRates = Readonly<Record<GoodsTruck, { perKm: number; minKm: number }>>;

/** The built-in rates (a city may set its own, fares/pricing.ts). */
export const GOODS_OUTSTATION_RATES: GoodsOutstationRates = {
  THREE_WHEELER: { perKm: 22, minKm: 40 },
  MINI_TRUCK: { perKm: 26, minKm: 40 },
  PICKUP: { perKm: 30, minKm: 40 },
  TRUCK: { perKm: 45, minKm: 40 },
};

/** Goods to another town, in the outstation terms' shape (one way, one day, no allowance). */
export function goodsOutstationTerms(kind: GoodsTruck, routeKm: number, rates: GoodsOutstationRates = GOODS_OUTSTATION_RATES): OutstationTerms {
  const r = rates[kind];
  const km = Math.round(routeKm * 10) / 10;
  return { mode: 'OUTSTATION', roundTrip: false, returnAt: null, days: 1, includedKm: Math.max(r.minKm, Math.ceil(km)), perKm: r.perKm, allowancePerDay: 0, routeKm: km };
}

// ---------------------------------------------------------------------------------------------- house shifting

export type HomeSize = 'FEW_ITEMS' | 'ONE_RK' | 'ONE_BHK' | 'TWO_BHK' | 'THREE_BHK';
export const HOME_SIZES: readonly HomeSize[] = ['FEW_ITEMS', 'ONE_RK', 'ONE_BHK', 'TWO_BHK', 'THREE_BHK'];

export type PackingLevel = 'NONE' | 'BASIC' | 'FULL';
export const PACKING_LEVELS: readonly PackingLevel[] = ['NONE', 'BASIC', 'FULL'];

/** One home size's suggested vehicle, the helpers included, packing and unpacking prices. */
export interface ShiftingSize {
  readonly vehicle: GoodsTruck;
  readonly helpers: number;
  readonly packing: { readonly BASIC: number; readonly FULL: number };
  readonly unpack: number;
}

/**
 * By home size: the suggested vehicle, the helpers included, packing (basic: wrap and tape; full: boxes, wrap and
 * bubble for the fragile) and unpacking at the new home.
 */
export const SHIFTING_SIZES: Readonly<Record<HomeSize, ShiftingSize>> = {
  FEW_ITEMS: { vehicle: 'THREE_WHEELER', helpers: 1, packing: { BASIC: 199, FULL: 399 }, unpack: 149 },
  ONE_RK: { vehicle: 'MINI_TRUCK', helpers: 2, packing: { BASIC: 399, FULL: 799 }, unpack: 299 },
  ONE_BHK: { vehicle: 'PICKUP', helpers: 2, packing: { BASIC: 699, FULL: 1299 }, unpack: 499 },
  TWO_BHK: { vehicle: 'TRUCK', helpers: 3, packing: { BASIC: 999, FULL: 1899 }, unpack: 699 },
  THREE_BHK: { vehicle: 'TRUCK', helpers: 4, packing: { BASIC: 1499, FULL: 2699 }, unpack: 999 },
};

export const SHIFTING_RATES = {
  /** Per helper for the job, in town / when they travel to another town. */
  helperCity: 450,
  helperBetween: 700,
  /** Per floor above the ground, at each end without a lift. */
  stairsPerFloor: 150,
  /** Per bed / wardrobe / table taken apart and put back together. */
  dismantlePerPiece: 199,
  /** Saturday and Sunday (IST): on everything. */
  weekendPct: 10,
  maxExtraHelpers: 4,
  maxDismantlePieces: 10,
  maxFloor: 30,
} as const;

/** Everything a shift's price depends on (a city may set its own, fares/pricing.ts). */
export interface ShiftingRates {
  readonly sizes: Readonly<Record<HomeSize, ShiftingSize>>;
  readonly helperCity: number;
  readonly helperBetween: number;
  readonly stairsPerFloor: number;
  readonly dismantlePerPiece: number;
  readonly weekendPct: number;
}

/** The built-in shifting prices. */
export const DEFAULT_SHIFTING_RATES: ShiftingRates = {
  sizes: SHIFTING_SIZES,
  helperCity: SHIFTING_RATES.helperCity,
  helperBetween: SHIFTING_RATES.helperBetween,
  stairsPerFloor: SHIFTING_RATES.stairsPerFloor,
  dismantlePerPiece: SHIFTING_RATES.dismantlePerPiece,
  weekendPct: SHIFTING_RATES.weekendPct,
};

/** Two-hour slots (IST start hours): 7–9 am … 4–6 pm. */
export const SHIFTING_SLOT_HOURS: readonly number[] = [7, 9, 11, 14, 16];

/** What the mover is asked to do (no item catalogue: the rider types each item). Stored in `Trip.shifting`. */
export interface ShiftingDetails {
  readonly homeSize: HomeSize;
  /** To another town: helpers at the travel rate, the vehicle by the km. */
  readonly between: boolean;
  readonly items: readonly { readonly name: string; readonly qty: number; readonly note?: string }[];
  readonly pickupFloor: number;
  readonly pickupLift: boolean;
  readonly dropFloor: number;
  readonly dropLift: boolean;
  readonly packing: PackingLevel;
  readonly dismantlePieces: number;
  readonly unpack: boolean;
  readonly extraHelpers: number;
}

/** The price lines of a shift (whole rupees, each rounded down). */
export interface ShiftingLines {
  readonly transport: number;
  readonly helperCount: number;
  readonly helpers: number;
  readonly stairs: number;
  readonly packing: number;
  readonly dismantle: number;
  readonly unpack: number;
  readonly subtotal: number;
  /** Saturday / Sunday: [SHIFTING_RATES.weekendPct] % of the subtotal. */
  readonly weekend: number;
  readonly total: number;
}

const IST_MS = 330 * 60_000;

/** Saturday or Sunday in India at [at]. */
export function isIstWeekend(at: Date): boolean {
  const day = new Date(at.getTime() + IST_MS).getUTCDay();
  return day === 0 || day === 6;
}

/** Floors climbed without a lift at one end (the ground floor is free). */
const stairsAt = (floor: number, lift: boolean): number => (lift ? 0 : Math.max(0, Math.floor(floor)));

/**
 * The lines for [d] with the vehicle's [transport] price (in town: the goods fare on the route; to another town:
 * [goodsOutstationTerms]' km × rate), on the day of [at].
 */
export function shiftingLines(
  d: Pick<ShiftingDetails, Exclude<keyof ShiftingDetails, 'items'>>,
  transport: number,
  at: Date,
  rates: ShiftingRates = DEFAULT_SHIFTING_RATES,
): ShiftingLines {
  const size = rates.sizes[d.homeSize];
  const helperCount = size.helpers + Math.min(SHIFTING_RATES.maxExtraHelpers, Math.max(0, Math.floor(d.extraHelpers)));
  const helpers = helperCount * (d.between ? rates.helperBetween : rates.helperCity);
  const stairs = (stairsAt(d.pickupFloor, d.pickupLift) + stairsAt(d.dropFloor, d.dropLift)) * rates.stairsPerFloor;
  const packing = d.packing === 'NONE' ? 0 : size.packing[d.packing];
  const dismantle = Math.min(SHIFTING_RATES.maxDismantlePieces, Math.max(0, Math.floor(d.dismantlePieces))) * rates.dismantlePerPiece;
  const unpack = d.unpack ? size.unpack : 0;
  const subtotal = transport + helpers + stairs + packing + dismantle + unpack;
  const weekend = isIstWeekend(at) ? Math.floor((subtotal * rates.weekendPct) / 100) : 0;
  return { transport, helperCount, helpers, stairs, packing, dismantle, unpack, subtotal, weekend, total: subtotal + weekend };
}
