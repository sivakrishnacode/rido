-- Admin list views: filters + newest-first ordering without full scans.
DROP INDEX "Trip_status_idx";
CREATE INDEX "Trip_status_createdAt_idx" ON "Trip"("status", "createdAt");
CREATE INDEX "Trip_createdAt_idx" ON "Trip"("createdAt");
CREATE INDEX "User_role_createdAt_idx" ON "User"("role", "createdAt");
CREATE INDEX "Driver_status_createdAt_idx" ON "Driver"("status", "createdAt");
CREATE INDEX "Driver_createdAt_idx" ON "Driver"("createdAt");
CREATE INDEX "KycDocument_status_updatedAt_idx" ON "KycDocument"("status", "updatedAt");
