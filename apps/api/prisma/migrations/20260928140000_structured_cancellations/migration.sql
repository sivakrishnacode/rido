-- CreateEnum
CREATE TYPE "CancelledBy" AS ENUM ('PASSENGER', 'DRIVER', 'SYSTEM', 'ADMIN');

-- CreateEnum
CREATE TYPE "CancelCode" AS ENUM ('CHANGED_MIND', 'DRIVER_TOO_FAR', 'DRIVER_ASKED_TO_CANCEL', 'WAIT_TOO_LONG', 'BOOKED_BY_MISTAKE', 'PASSENGER_NO_SHOW', 'PASSENGER_UNREACHABLE', 'PASSENGER_ASKED_TO_CANCEL', 'VEHICLE_ISSUE', 'TOO_FAR', 'BUTTERFLY_MISMATCH', 'NO_DRIVERS', 'DRIVER_NOT_MOVING', 'STUCK', 'OTHER');

-- AlterTable
ALTER TABLE "Trip" ADD COLUMN     "arrivedAt" TIMESTAMP(3),
ADD COLUMN     "cancelCode" "CancelCode",
ADD COLUMN     "cancelledAt" TIMESTAMP(3),
ADD COLUMN     "cancelledBy" "CancelledBy";

-- CreateTable
CREATE TABLE "TripCancellation" (
    "id" TEXT NOT NULL,
    "tripId" TEXT NOT NULL,
    "driverId" TEXT,
    "passengerId" TEXT NOT NULL,
    "by" "CancelledBy" NOT NULL,
    "code" "CancelCode" NOT NULL,
    "note" TEXT,
    "fromStatus" "TripStatus" NOT NULL,
    "reassigned" BOOLEAN NOT NULL DEFAULT false,
    "isDriverFault" BOOLEAN NOT NULL DEFAULT false,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "TripCancellation_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "TripCancellation_tripId_idx" ON "TripCancellation"("tripId");

-- CreateIndex
CREATE INDEX "TripCancellation_driverId_createdAt_idx" ON "TripCancellation"("driverId", "createdAt");

-- CreateIndex
CREATE INDEX "TripCancellation_passengerId_createdAt_idx" ON "TripCancellation"("passengerId", "createdAt");

-- AddForeignKey
ALTER TABLE "TripCancellation" ADD CONSTRAINT "TripCancellation_tripId_fkey" FOREIGN KEY ("tripId") REFERENCES "Trip"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "TripCancellation" ADD CONSTRAINT "TripCancellation_driverId_fkey" FOREIGN KEY ("driverId") REFERENCES "Driver"("id") ON DELETE SET NULL ON UPDATE CASCADE;


-- Backfill (best effort): who cancelled and why, from the reason texts the apps sent before codes existed.
UPDATE "Trip" SET "cancelledBy" = 'DRIVER', "cancelCode" = CASE "cancelReason"
    WHEN 'Rider is not a woman' THEN 'BUTTERFLY_MISMATCH'::"CancelCode"
    WHEN 'Passenger not reachable' THEN 'PASSENGER_UNREACHABLE'::"CancelCode"
    WHEN 'Passenger asked me to cancel' THEN 'PASSENGER_ASKED_TO_CANCEL'::"CancelCode"
    WHEN 'Pickup is too far' THEN 'TOO_FAR'::"CancelCode"
    WHEN 'Vehicle problem' THEN 'VEHICLE_ISSUE'::"CancelCode"
    ELSE 'OTHER'::"CancelCode" END
  WHERE "status" = 'CANCELLED' AND "cancelReason" IN ('Rider is not a woman', 'Passenger not reachable', 'Passenger asked me to cancel', 'Pickup is too far', 'Vehicle problem', 'Other reason');

UPDATE "Trip" SET "cancelledBy" = 'PASSENGER', "cancelCode" = CASE "cancelReason"
    WHEN 'Driver too far' THEN 'DRIVER_TOO_FAR'::"CancelCode"
    WHEN 'Changed my plan' THEN 'CHANGED_MIND'::"CancelCode"
    WHEN 'Cancelled while searching' THEN 'CHANGED_MIND'::"CancelCode"
    WHEN 'Cancelled by sender' THEN 'CHANGED_MIND'::"CancelCode"
    WHEN 'Booked by mistake' THEN 'BOOKED_BY_MISTAKE'::"CancelCode"
    ELSE 'OTHER'::"CancelCode" END
  WHERE "status" = 'CANCELLED' AND "cancelledBy" IS NULL;

UPDATE "Trip" SET "cancelledBy" = 'SYSTEM', "cancelCode" = 'NO_DRIVERS' WHERE "status" = 'NO_DRIVERS';

UPDATE "Trip" SET "cancelledAt" = GREATEST("createdAt", "assignedAt", "startedAt") WHERE "cancelledBy" IS NOT NULL;

-- History rows for the old cancels, so cancellation rates include them.
INSERT INTO "TripCancellation" ("id", "tripId", "driverId", "passengerId", "by", "code", "note", "fromStatus", "isDriverFault", "createdAt")
  SELECT gen_random_uuid()::text, "id", "driverId", "passengerId", "cancelledBy", "cancelCode", "cancelReason",
         CASE WHEN "driverId" IS NULL THEN 'SEARCHING'::"TripStatus" ELSE 'DRIVER_ASSIGNED'::"TripStatus" END,
         "cancelledBy" = 'DRIVER' AND "cancelCode" <> 'BUTTERFLY_MISMATCH', "cancelledAt"
  FROM "Trip" WHERE "status" = 'CANCELLED';
