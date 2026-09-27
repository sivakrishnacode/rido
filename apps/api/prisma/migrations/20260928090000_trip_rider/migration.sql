-- "Who's riding?": a trip booked for someone else carries the rider's name and phone (the driver sees and calls them).
-- riderIsWoman lets a Butterfly (women drivers) ride be booked for a woman from any account.
ALTER TABLE "Trip" ADD COLUMN "riderName" TEXT;
ALTER TABLE "Trip" ADD COLUMN "riderPhone" TEXT;
ALTER TABLE "Trip" ADD COLUMN "riderIsWoman" BOOLEAN NOT NULL DEFAULT false;
