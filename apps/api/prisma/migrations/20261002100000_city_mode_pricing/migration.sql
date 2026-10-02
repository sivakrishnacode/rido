-- Per-city prices for rentals, outstation, goods to another town and house shifting (fares/pricing.ts), edited in
-- admin › City › Rentals & more. A null section uses the built-in rates.
CREATE TABLE "CityModePricing" (
    "cityId" TEXT NOT NULL,
    "rental" JSONB,
    "outstation" JSONB,
    "goodsOutstation" JSONB,
    "shifting" JSONB,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "CityModePricing_pkey" PRIMARY KEY ("cityId")
);

ALTER TABLE "CityModePricing" ADD CONSTRAINT "CityModePricing_cityId_fkey" FOREIGN KEY ("cityId") REFERENCES "City"("id") ON DELETE CASCADE ON UPDATE CASCADE;
