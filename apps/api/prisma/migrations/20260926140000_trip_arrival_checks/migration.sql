-- AlterTable
ALTER TABLE "Trip" ADD COLUMN     "arrivedDistanceM" INTEGER,
ADD COLUMN     "arrivedFarReason" TEXT,
ADD COLUMN     "endDistanceM" INTEGER,
ADD COLUMN     "endFarReason" TEXT;
