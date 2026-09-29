# @tamiltaxi/api

The Tamil Taxi backend: NestJS 12 (ESM), Prisma 7 on Postgres 17, Redis 7, and Socket.IO (namespace `/rt`).

```bash
docker compose up -d postgres redis              # from the repo root
cp apps/api/.env.example apps/api/.env
npm run prisma:deploy -w @tamiltaxi/api && npm run prisma:seed -w @tamiltaxi/api
npm run start:dev -w @tamiltaxi/api                   # http://localhost:3000, REST under /v1
```

| Command | What |
|---|---|
| `npm run analyze -w @tamiltaxi/api` | `tsc --noEmit` + oxlint |
| `npm test -w @tamiltaxi/api` | Unit tests (Vitest) |
| `npm run test:e2e -w @tamiltaxi/api` | Full flows against an isolated `tamiltaxi_test` DB and Redis DB 1 |
| `npm run prisma:migrate -w @tamiltaxi/api` | New migration (dev) |
| `npm run seed:test-drivers -w @tamiltaxi/api` | 11 approved test drivers |
| `npm run seed:demo-trips -w @tamiltaxi/api` | ~2,000 demo trips for heatmaps (then `seed:demo-people`) |

Layout:

- `src/core`: config (`env.ts`), auth guards, Prisma, Redis, storage (S3 or local disk)
- `src/modules/*`: one module per domain: admin, app-config, auth, drivers, fares, geo (H3), health, kyc, maps,
  notifications, places, realtime, safety, settings, subscriptions, support, trips, users

**Dev sign-in:** with `OTP_DEV_MODE=true` (no SMS), `DEV_OTP_CODE` is the only code that works. Without it, any 6
digits except `000000` work, and that is refused in production.

Every endpoint, setting, Redis key and algorithm (dispatch, surge, ETA, fares) is described in
[docs/tech-docs/using.tech.md §6](../../docs/tech-docs/using.tech.md#6-backend-appsapi).

**Prisma queries are lazy:** `void prisma.x.create(...)` never runs. Always `await` it or attach `.catch()`.
