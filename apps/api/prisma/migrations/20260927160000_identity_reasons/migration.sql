-- What the user must fix after a declined identity check, in plain words (shown in the apps).
ALTER TABLE "IdentityVerification" ADD COLUMN "reasons" JSONB;
