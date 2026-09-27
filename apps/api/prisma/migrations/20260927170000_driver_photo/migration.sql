-- The driver's verified selfie (from the Didit liveness check), shown to riders on their trip.
ALTER TABLE "Driver" ADD COLUMN "photoFile" TEXT;
ALTER TABLE "Driver" ADD COLUMN "photoUpdatedAt" TIMESTAMP(3);
