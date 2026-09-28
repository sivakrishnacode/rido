-- CreateEnum
CREATE TYPE "CancelFault" AS ENUM ('DRIVER', 'PASSENGER', 'NONE', 'SHARED');

-- AlterTable
ALTER TABLE "TripCancellation" ADD COLUMN     "fault" "CancelFault" NOT NULL DEFAULT 'NONE',
ADD COLUMN     "faultRule" TEXT,
ADD COLUMN     "signals" JSONB;

-- Backfill (best effort, no signals were recorded): the old isDriverFault flag, and the driver cancels that were
-- the passenger's doing.
UPDATE "TripCancellation" SET "fault" = 'DRIVER', "faultRule" = 'backfill' WHERE "isDriverFault";
UPDATE "TripCancellation" SET "fault" = 'PASSENGER', "faultRule" = 'backfill'
  WHERE "by" = 'DRIVER' AND "code" IN ('PASSENGER_NO_SHOW', 'BUTTERFLY_MISMATCH');
