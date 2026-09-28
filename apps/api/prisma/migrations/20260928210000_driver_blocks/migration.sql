-- CreateEnum
CREATE TYPE "DriverBlockReason" AS ENUM ('CANCELLATION_RATE');

-- AlterTable
ALTER TABLE "Driver" ADD COLUMN     "blockedUntil" TIMESTAMP(3);

-- CreateTable
CREATE TABLE "DriverBlock" (
    "id" TEXT NOT NULL,
    "driverId" TEXT NOT NULL,
    "reason" "DriverBlockReason" NOT NULL,
    "fromAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "untilAt" TIMESTAMP(3) NOT NULL,
    "liftedBy" TEXT,
    "liftedAt" TIMESTAMP(3),
    "details" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "DriverBlock_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "DriverBlock_driverId_fromAt_idx" ON "DriverBlock"("driverId", "fromAt");

-- AddForeignKey
ALTER TABLE "DriverBlock" ADD CONSTRAINT "DriverBlock_driverId_fkey" FOREIGN KEY ("driverId") REFERENCES "Driver"("id") ON DELETE CASCADE ON UPDATE CASCADE;

