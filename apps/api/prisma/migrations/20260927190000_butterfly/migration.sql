-- Butterfly: a woman rider can ask for women drivers first (PREFERRED) or only (ONLY) on a trip.
CREATE TYPE "WomenDriverPref" AS ENUM ('NONE', 'PREFERRED', 'ONLY');
ALTER TABLE "Trip" ADD COLUMN "womenDriver" "WomenDriverPref" NOT NULL DEFAULT 'NONE';
