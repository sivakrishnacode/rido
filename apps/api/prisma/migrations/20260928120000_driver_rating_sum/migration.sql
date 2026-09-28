-- Driver rating = sum / count of passengers' ratings. Before, it was averaged over ridesCount, which counts unrated
-- rides (and already included the trip being rated). Backfill from the trips rated so far.
ALTER TABLE "Driver" ADD COLUMN "ratingSum" INTEGER NOT NULL DEFAULT 0;
ALTER TABLE "Driver" ADD COLUMN "ratingCount" INTEGER NOT NULL DEFAULT 0;

UPDATE "Driver" d
SET "ratingSum" = r.total, "ratingCount" = r.n, "rating" = ROUND(r.total::numeric / r.n, 2)
FROM (
  SELECT "driverId", SUM("rating")::int AS total, COUNT(*)::int AS n
  FROM "Trip"
  WHERE "rating" IS NOT NULL AND "driverId" IS NOT NULL
  GROUP BY "driverId"
) r
WHERE d."id" = r."driverId";
