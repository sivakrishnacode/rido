-- Drivers scan both their driving licence and Aadhaar: keep each document's type and last 4 digits.
ALTER TABLE "IdentityVerification" ADD COLUMN "documents" JSONB;
