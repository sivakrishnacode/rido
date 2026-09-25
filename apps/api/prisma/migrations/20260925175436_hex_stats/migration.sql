-- CreateTable
CREATE TABLE "HexStat" (
    "fromCell" TEXT NOT NULL,
    "toCell" TEXT NOT NULL,
    "hour" INTEGER NOT NULL,
    "trips" INTEGER NOT NULL,
    "avgSpeedKmh" DOUBLE PRECISION NOT NULL,
    "avgDurationMin" DOUBLE PRECISION NOT NULL,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "HexStat_pkey" PRIMARY KEY ("fromCell","toCell","hour")
);

-- CreateIndex
CREATE INDEX "HexStat_fromCell_idx" ON "HexStat"("fromCell");
