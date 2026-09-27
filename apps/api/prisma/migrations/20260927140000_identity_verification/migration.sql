-- Didit identity checks (selfie + ID). Drivers need one to be approved; riders get a "Verified" badge.
CREATE TYPE "IdentityStatus" AS ENUM ('NOT_STARTED', 'IN_PROGRESS', 'IN_REVIEW', 'APPROVED', 'DECLINED');
CREATE TYPE "IdentityPurpose" AS ENUM ('DRIVER', 'RIDER');

ALTER TABLE "User" ADD COLUMN "identityStatus" "IdentityStatus" NOT NULL DEFAULT 'NOT_STARTED';
ALTER TABLE "User" ADD COLUMN "identityVerifiedAt" TIMESTAMP(3);

CREATE TABLE "IdentityVerification" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "purpose" "IdentityPurpose" NOT NULL,
    "sessionId" TEXT NOT NULL,
    "status" "IdentityStatus" NOT NULL DEFAULT 'NOT_STARTED',
    "providerStatus" TEXT NOT NULL DEFAULT 'Not Started',
    "documentType" TEXT,
    "documentLast4" TEXT,
    "fullName" TEXT,
    "dateOfBirth" TEXT,
    "warnings" JSONB,
    "decidedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "IdentityVerification_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "IdentityVerification_sessionId_key" ON "IdentityVerification"("sessionId");
CREATE INDEX "IdentityVerification_userId_createdAt_idx" ON "IdentityVerification"("userId", "createdAt");
ALTER TABLE "IdentityVerification" ADD CONSTRAINT "IdentityVerification_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
