-- House shifting: what the mover is asked to do (home size, typed items, floors and lifts, packing, extras) and its
-- price lines (fares/goods-modes.ts ShiftingDetails + ShiftingLines). Null for every other trip.
ALTER TABLE "Trip" ADD COLUMN "shifting" JSONB;
