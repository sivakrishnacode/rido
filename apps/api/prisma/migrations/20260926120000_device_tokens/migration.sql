-- CreateEnum
CREATE TYPE "AppKind" AS ENUM ('PASSENGER', 'DRIVER');

-- CreateTable
CREATE TABLE "DeviceToken" (
    "token" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "app" "AppKind" NOT NULL,
    "platform" TEXT NOT NULL DEFAULT 'android',
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "DeviceToken_pkey" PRIMARY KEY ("token")
);

-- CreateIndex
CREATE INDEX "DeviceToken_userId_app_idx" ON "DeviceToken"("userId", "app");

-- AddForeignKey
ALTER TABLE "DeviceToken" ADD CONSTRAINT "DeviceToken_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
