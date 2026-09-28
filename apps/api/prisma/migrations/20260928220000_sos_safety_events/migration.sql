-- CreateEnum
CREATE TYPE "SafetyParty" AS ENUM ('PASSENGER', 'DRIVER');

-- CreateEnum
CREATE TYPE "SosStatus" AS ENUM ('OPEN', 'ACKNOWLEDGED', 'RESOLVED', 'FALSE_ALARM');

-- CreateEnum
CREATE TYPE "SafetyEventKind" AS ENUM ('STOP', 'DEVIATION', 'NIGHT_CHECK', 'SOS_LINKED');

-- CreateTable
CREATE TABLE "Sos" (
    "id" TEXT NOT NULL,
    "tripId" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "role" "SafetyParty" NOT NULL,
    "lat" DOUBLE PRECISION,
    "lng" DOUBLE PRECISION,
    "status" "SosStatus" NOT NULL DEFAULT 'OPEN',
    "source" TEXT NOT NULL DEFAULT 'BUTTON',
    "note" TEXT,
    "acknowledgedAt" TIMESTAMP(3),
    "acknowledgedBy" TEXT,
    "resolvedAt" TIMESTAMP(3),
    "resolvedBy" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Sos_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "SafetyEvent" (
    "id" TEXT NOT NULL,
    "tripId" TEXT NOT NULL,
    "kind" "SafetyEventKind" NOT NULL,
    "payload" JSONB,
    "at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "SafetyEvent_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "Sos_status_createdAt_idx" ON "Sos"("status", "createdAt");

-- CreateIndex
CREATE INDEX "Sos_tripId_idx" ON "Sos"("tripId");

-- CreateIndex
CREATE INDEX "SafetyEvent_tripId_at_idx" ON "SafetyEvent"("tripId", "at");

-- CreateIndex
CREATE INDEX "SafetyEvent_kind_at_idx" ON "SafetyEvent"("kind", "at");

-- AddForeignKey
ALTER TABLE "Sos" ADD CONSTRAINT "Sos_tripId_fkey" FOREIGN KEY ("tripId") REFERENCES "Trip"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Sos" ADD CONSTRAINT "Sos_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "SafetyEvent" ADD CONSTRAINT "SafetyEvent_tripId_fkey" FOREIGN KEY ("tripId") REFERENCES "Trip"("id") ON DELETE CASCADE ON UPDATE CASCADE;

