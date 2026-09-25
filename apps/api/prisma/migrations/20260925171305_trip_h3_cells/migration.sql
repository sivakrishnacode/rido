-- AlterTable
ALTER TABLE "Trip" ADD COLUMN     "dropCell" TEXT,
ADD COLUMN     "pickupCell" TEXT;

-- CreateIndex
CREATE INDEX "Trip_pickupCell_idx" ON "Trip"("pickupCell");

-- CreateIndex
CREATE INDEX "Trip_dropCell_idx" ON "Trip"("dropCell");
