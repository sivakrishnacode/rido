-- "Book any": extra vehicle kinds a searching trip may be matched with, and their fare quotes.
ALTER TABLE "Trip" ADD COLUMN "alsoKinds" "VehicleKind"[] DEFAULT ARRAY[]::"VehicleKind"[];
ALTER TABLE "Trip" ADD COLUMN "alsoFares" JSONB;
