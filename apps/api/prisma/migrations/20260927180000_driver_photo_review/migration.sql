-- The driver takes their profile photo in the app; it is matched (Didit Face Match) against the live selfie from
-- their approved identity check. Unclear matches wait for an admin.
ALTER TABLE "Driver" ADD COLUMN "selfieFile" TEXT;
ALTER TABLE "Driver" ADD COLUMN "pendingPhotoFile" TEXT;
ALTER TABLE "Driver" ADD COLUMN "photoMatchScore" DOUBLE PRECISION;
ALTER TABLE "Driver" ADD COLUMN "photoRejectReason" TEXT;
