#!/usr/bin/env sh
# Runs the e2e suite against an isolated database (tamiltaxi_test) and Redis DB 1, so tests never touch dev data.
set -e
cd "$(dirname "$0")/.."
BASE_DB="${DATABASE_URL:-postgresql://tamiltaxi:tamiltaxi@localhost:5432/tamiltaxi?schema=public}"
REDIS_BASE="${REDIS_URL:-redis://localhost:6380}"
if [ -f .env ]; then
  if [ -z "${DATABASE_URL:-}" ]; then
    BASE_DB="$(grep '^DATABASE_URL=' .env | cut -d= -f2- | tr -d '"')"
  fi
  if [ -z "${REDIS_URL:-}" ]; then
    REDIS_BASE="$(grep '^REDIS_URL=' .env | cut -d= -f2- | tr -d '"')"
  fi
fi
export DATABASE_URL="$(echo "$BASE_DB" | sed -E 's#/([a-z_]+)\?#/tamiltaxi_test?#')"
export REDIS_URL="${REDIS_BASE%/}/1"
export GOOGLE_MAPS_API_KEY=""
npx prisma migrate deploy >/dev/null
npx tsx prisma/seed.ts >/dev/null
npx vitest run --config ./vitest.config.e2e.ts "$@"
