-- AlterTable
ALTER TABLE "Trip" ADD COLUMN     "actualDistanceM" INTEGER,
ADD COLUMN     "approachDistanceM" INTEGER,
ADD COLUMN     "distanceCalcFailed" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "gpsMockCount" INTEGER NOT NULL DEFAULT 0,
ADD COLUMN     "gpsPoints" INTEGER NOT NULL DEFAULT 0,
ADD COLUMN     "pathPolyline" TEXT;
