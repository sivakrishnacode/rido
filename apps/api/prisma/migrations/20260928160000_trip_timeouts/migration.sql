-- AlterTable
ALTER TABLE "Trip" ADD COLUMN     "acceptDistanceM" INTEGER,
ADD COLUMN     "needsReview" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "noShowAt" TIMESTAMP(3),
ADD COLUMN     "reviewNote" TEXT;

-- CreateIndex
CREATE INDEX "Trip_needsReview_idx" ON "Trip"("needsReview");

