-- CreateEnum
CREATE TYPE "DueStatus" AS ENUM ('PENDING', 'APPLIED');

-- CreateTable
CREATE TABLE "CancellationDue" (
    "id" TEXT NOT NULL,
    "passengerId" TEXT NOT NULL,
    "tripId" TEXT NOT NULL,
    "cancellationId" TEXT,
    "owedToDriverId" TEXT NOT NULL,
    "amount" INTEGER NOT NULL,
    "status" "DueStatus" NOT NULL DEFAULT 'PENDING',
    "appliedTripId" TEXT,
    "appliedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "CancellationDue_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "CancellationDue_cancellationId_key" ON "CancellationDue"("cancellationId");

-- CreateIndex
CREATE INDEX "CancellationDue_passengerId_status_idx" ON "CancellationDue"("passengerId", "status");

-- CreateIndex
CREATE INDEX "CancellationDue_owedToDriverId_createdAt_idx" ON "CancellationDue"("owedToDriverId", "createdAt");

-- CreateIndex
CREATE INDEX "CancellationDue_status_createdAt_idx" ON "CancellationDue"("status", "createdAt");

-- AddForeignKey
ALTER TABLE "CancellationDue" ADD CONSTRAINT "CancellationDue_passengerId_fkey" FOREIGN KEY ("passengerId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CancellationDue" ADD CONSTRAINT "CancellationDue_tripId_fkey" FOREIGN KEY ("tripId") REFERENCES "Trip"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CancellationDue" ADD CONSTRAINT "CancellationDue_appliedTripId_fkey" FOREIGN KEY ("appliedTripId") REFERENCES "Trip"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CancellationDue" ADD CONSTRAINT "CancellationDue_owedToDriverId_fkey" FOREIGN KEY ("owedToDriverId") REFERENCES "Driver"("id") ON DELETE CASCADE ON UPDATE CASCADE;

