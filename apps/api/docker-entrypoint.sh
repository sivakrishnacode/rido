#!/bin/sh
# Applies migrations, seeds reference data (idempotent), then starts the API.
set -e
npx prisma migrate deploy
if [ "${SEED_ON_START:-true}" = "true" ]; then npx tsx prisma/seed.ts; fi
exec node dist/main.js
