-- Cab rentals and outstation trips (RideMode, Trip.modeTerms) and trips booked for later (SCHEDULED, scheduledAt).
CREATE TYPE "RideMode" AS ENUM ('LOCAL', 'RENTAL', 'OUTSTATION');
ALTER TYPE "TripStatus" ADD VALUE IF NOT EXISTS 'SCHEDULED' BEFORE 'SEARCHING';

ALTER TABLE "Trip" ADD COLUMN "rideMode" "RideMode" NOT NULL DEFAULT 'LOCAL',
ADD COLUMN "modeTerms" JSONB,
ADD COLUMN "scheduledAt" TIMESTAMP(3),
ADD COLUMN "searchFrom" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP;

-- Existing trips searched from when they were booked.
UPDATE "Trip" SET "searchFrom" = "createdAt";

CREATE INDEX "Trip_status_scheduledAt_idx" ON "Trip"("status", "scheduledAt");
