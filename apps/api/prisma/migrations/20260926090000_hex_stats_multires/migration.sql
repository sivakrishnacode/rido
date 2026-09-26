-- AlterTable
ALTER TABLE "HexStat" ADD COLUMN     "res" INTEGER NOT NULL DEFAULT 7;

-- CreateIndex
CREATE INDEX "HexStat_res_trips_idx" ON "HexStat"("res", "trips");
