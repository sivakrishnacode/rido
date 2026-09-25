# Rido: Technology & DevOps

Single technical reference for the Rido monorepo. Keep it current: update this file whenever the stack, services,
environment variables, commands or infrastructure change.

Last updated: 25 Sep 2026

---

## Owner recommendations

Notes from the owner. Each item gets a status and a plan once reviewed.

| # | Recommendation | Status | Plan |
|---|---|---|---|
| 1 | https://h3geo.org - opensource for geo data anlysing and driver - user match, ETA finding and more | In progress: service areas, zones and **driver matching** done (H3 rings + road ETA per hex pair + 2 s batches); hex demand stats and historical ETA next | See [H3 plan](#h3-plan-owner-recommendation-1) |

---

## 1. Stack at a glance

| Layer | Technology | Version | Where |
|---|---|---|---|
| Monorepo | Turborepo + npm workspaces | turbo 2.11, npm 11, Node 24 | root `package.json`, `turbo.json` |
| Mobile apps | Flutter (Material 3), Android only | Flutter 3.47 / Dart 3.13 | `apps/passenger`, `apps/driver` |
| App state / routing | Riverpod 3, go_router 17 (pinned: 18 needs `material_ui`) | | `lib/state`, `lib/router` |
| Shared Flutter code | `rido_ui` (theme, widgets), `rido_data` (models, seed, fare engine, repositories, simulator) | | `packages/` |
| Backend | NestJS 12 (ESM), TypeScript 5.9 | | `apps/api` |
| ORM / DB | Prisma 7 (driver adapter `@prisma/adapter-pg`) + PostgreSQL 17 | | `apps/api/prisma` |
| Cache / realtime state | Redis 7 (ioredis 6) | | docker `redis` |
| Realtime | Socket.IO (`@nestjs/platform-socket.io`), namespace `/rt` | | `apps/api/src/modules/realtime` |
| Auth | Phone OTP (Redis) → JWT (`@nestjs/jwt`) | | `apps/api/src/modules/auth` |
| Maps (apps) | Google Maps SDK for Android when a key is set, else flutter_map + CARTO light tiles | | `packages/rido_ui` RidoMap |
| Maps (APIs) | Google Places API (New), Geocoding API, Routes API; fallback OSRM public router + seed data | | `apps/api/src/modules/maps`, `rido_data` |
| Location | geolocator (Android fine/coarse location) | 14.x | passenger app |
| Admin panel | Next.js (App Router, Turbopack, `output: 'standalone'`), React, TypeScript | Next 16.3, React 19.3, TS 5.9 | `apps/admin` |
| Admin UI | shadcn/ui (radix-nova style, Radix UI), Tailwind CSS v4, lucide-react, sonner toasts, Recharts (shadcn chart) | shadcn 4.21, radix-ui 1.6, Tailwind 4.3, Recharts 3.8 | `apps/admin/src/components/ui` |
| Admin maps | Leaflet + react-leaflet (CARTO light tiles), h3-js for hexagons | Leaflet 1.9, react-leaflet 5, h3-js 4.5 | `apps/admin/src/components/map`, `src/lib/hex.ts` |
| Tests | Flutter test (widget + flow), Vitest 4 (API unit + e2e, admin unit) | | `apps/*/test`, `packages/*/test` |
| Lint | `flutter analyze` (flutter_lints), oxlint + `tsc --noEmit` (API), ESLint 9 (`eslint-config-next`) + `tsc --noEmit` (admin) | | per package |
| Containers | Docker, Docker Compose | Docker 29, Compose 5 | `docker-compose.yml`, `apps/api/Dockerfile`, `apps/admin/Dockerfile` |

---

## 2. Repository layout

```
apps/
  api/                @rido/api        NestJS backend (Prisma, Redis, Socket.IO)
  admin/              @rido/admin      Next.js admin panel (shadcn/ui, Leaflet + H3 map editor), port 3001
  passenger/          @rido/passenger  Flutter passenger app (com.rido.passenger)
  driver/             @rido/driver     Flutter driver app (com.rido.driver)
packages/
  rido_ui/            @rido/ui         theme, widgets, illustrations, bundled fonts
  rido_data/          @rido/data       models, seed, fare engine, repositories, simulator, road router
docs/
  tech-docs/using.tech.md  this file
  BUSINESS_MODEL.md, PITCH.md, PLAN.md, UI_PROMPTS.md, FLUTTER_PROMPT.md, design/
scripts/              flutter.sh, dart.sh (SDK lookup), build_apks.sh
docker-compose.yml    postgres + redis + api + admin (+ tools profile)
turbo.json            task pipeline
```

---

## 3. Commands

| Command | What it does |
|---|---|
| `npm install` | Installs Turborepo, API and admin dependencies (one workspace lockfile) |
| `npm run get` | `flutter pub get` in Flutter packages, `prisma generate` in the API |
| `npm run analyze` | `flutter analyze` / `tsc --noEmit` + oxlint (API) / `next typegen` + `tsc --noEmit` + ESLint (admin) |
| `npm test` | Flutter tests, API unit tests, admin unit tests (Vitest) |
| `npm run check` | analyze + test (cached by Turborepo) |
| `npm run build:apk` | Release APKs → `dist/rido-passenger.apk`, `dist/rido-driver.apk` |
| `./scripts/build_apks.sh [passenger\|driver] [--split]` | Same without Node; one app or both; `--split` = per-CPU APKs (~20 MB); checks the map key is in the APK |
| `npm run passenger` / `npm run driver` | `flutter run` for that app |
| `npm run start:dev -w @rido/api` | API with watch mode (needs Postgres + Redis) |
| `npm run test:e2e -w @rido/api` | API end-to-end tests against real Postgres + Redis |
| `npm run prisma:migrate -w @rido/api` | Create/apply a migration in development |
| `npm run prisma:deploy -w @rido/api` | Apply migrations (CI / production) |
| `npm run prisma:seed -w @rido/api` | Seed places and plan prices (idempotent) |
| `npm run dev -w @rido/admin` | Admin panel on http://localhost:3001 (needs the API; `API_URL` defaults to `http://localhost:3000/v1`) |
| `npm run build -w @rido/admin` / `npm run start -w @rido/admin` | Production build / serve on :3001 |
| `npm run test -w @rido/admin` | Admin unit tests (formatters, paging URLs, API helpers, JWT check, fare preview, H3 helpers, settings validation) |
| `docker compose up -d` | Postgres + Redis + API + admin panel |
| `docker compose up -d --build admin` | Rebuild and restart only the admin panel |
| `docker compose --profile tools up -d` | Also Adminer and Redis Insight |

Flutter is found via `$FLUTTER`, `PATH`, or `~/development/flutter` (`scripts/flutter.sh`).

---

## 4. Services and ports (Docker Compose)

| Service | Image | Host port (default) | Notes |
|---|---|---|---|
| postgres | postgres:17-alpine | 5432 | volume `postgres-data`, healthcheck `pg_isready` |
| redis | redis:7-alpine | 6379 (this machine uses **6380**, set in `.env`) | AOF on, volume `redis-data` |
| api | built from `apps/api/Dockerfile` | 3000 | runs `prisma migrate deploy` + seed, then `node dist/main.js`; healthcheck `/health` |
| admin | built from `apps/admin/Dockerfile` (`rido-admin:local`) | 3001 (`ADMIN_PORT`) | Next standalone `node apps/admin/server.js`; talks to `http://api:3000/v1`; starts after api is healthy; healthcheck `/login` |
| adminer | adminer:5 (profile `tools`) | 8080 | DB browser |
| redis-insight | redis/redisinsight (profile `tools`) | 5540 | Redis browser |

API and admin images: multi-stage Node 24 alpine builds from the repo root (every workspace `package.json` is copied
so `npm ci` matches the lockfile), run as non-root `rido`, `tini` as PID 1. The admin image is ~300 MB.

---

## 5. Environment variables

All actual keys, passwords and fingerprints live in `docs/tech-docs/credentials.local.md` (git-ignored; template:
`credentials.example.md`). App compile-time keys live in `/.dart-defines.json` (git-ignored; template
`.dart-defines.example.json`), passed automatically by `scripts/flutter.sh` to every `flutter run` / `flutter build`.


Root `.env` (Compose) is copied from `.env.example`; API local dev uses `apps/api/.env` (from `apps/api/.env.example`).
Never commit real `.env` files.

| Variable | Used by | Default | Notes |
|---|---|---|---|
| `POSTGRES_USER` / `POSTGRES_PASSWORD` / `POSTGRES_DB` | compose | rido / rido / rido | |
| `POSTGRES_PORT`, `REDIS_PORT`, `API_PORT` | compose | 5432, 6379, 3000 | host ports |
| `DATABASE_URL` | API, Prisma | set by compose | `postgresql://…?schema=public` |
| `REDIS_URL` | API | set by compose | |
| `JWT_SECRET` | API | dev placeholder | ≥ 32 chars in production (`openssl rand -hex 32`) |
| `JWT_EXPIRES_IN` | API | 30d | |
| `OTP_DEV_MODE` | API | true | true = any 6-digit OTP except 000000 works |
| `CORS_ORIGINS` | API | `*` | comma-separated list in production |
| `SEED_ON_START` | API container | true | re-runs the idempotent seed on boot |
| `GOOGLE_MAPS_API_KEY` | API | empty | key 2 `rido-server` (IP-restricted): Places (New), Geocoding, Routes; empty = local fallback |
| `GOOGLE_MAPS_API_KEY` (dart-define) | Flutter apps | empty | key 3 `rido-app-services` (API-restricted only): the apps' direct Places/Geocoding/Routes calls; also switches the map to Google |
| `/.dart-defines.json` | `scripts/flutter.sh` (run/build) | absent | holds `GOOGLE_MAPS_API_KEY` for the apps |
| `MAPS_API_KEY` (`/.dart-defines.json`, else `apps/*/android/local.properties` or env) | Android manifest | empty | key 1 `rido-android-maps` (package + SHA-1 restricted): Maps SDK for Android |
| `CARTO_KEY` (dart-define) | Flutter apps | built-in | CARTO basemap key (`?key=`), used when Google Maps is off |
| `ADMIN_PHONES` | API | empty (`.env.example`: 9000000001) | comma-separated phones that always sign in as ADMIN (admin panel login); the API container reads it on start |
| `API_URL` | admin (server side only) | `http://localhost:3000/v1`; compose sets `http://api:3000/v1` | the browser never calls the API directly |
| `ADMIN_PORT` | compose | 3001 | admin host port |
| `ADMIN_COOKIE_SECURE` → `COOKIE_SECURE` | admin container | false | `true` once served over HTTPS (session cookie gets `Secure`); outside compose, `NODE_ENV=production` sets Secure unless `COOKIE_SECURE=false` |
| `NEXT_PUBLIC_CARTO_KEY` | admin (build time, client bundle) | built-in CARTO key | basemap key for the admin maps; compose passes it as a build arg |

---

## 6. Backend (apps/api)

- **Modules:** core (config, Prisma, Redis, JWT guard, roles guard, validation pipe, error filter), settings, geo (H3),
  health, auth, users, places, maps, fares, drivers, subscriptions, trips (dispatch), realtime, support, admin.
- **H3 service areas:** each `City` stores its service area as H3 cells (`serviceCells`, default resolution 8 ≈ 0.74 km²
  per hex). `Zone`s group cells as SURGE (multiplier 1.0–1.5), DEMAND, NO_SERVICE or PICKUP_POINT. `GeoService.locate`
  (cached 30 s, invalidated on admin edits) decides serviceability, city, zones and the fare multiplier for any point.
  Bookings with a pickup or drop outside the hexes (or in a NO_SERVICE zone) are refused. Seed: Coimbatore, 1,519 cells
  (18 km) + 3 DEMAND zones. With no cities configured, everything is serviceable.
- **Per-city fares:** `CityFareRule` overrides the built-in rates per vehicle; the surge zone or `currentMultiplier`
  setting sets the multiplier, capped by `maxMultiplier`.
- **Settings (`AppSetting`):** currentMultiplier, maxMultiplier, searchRadiusKm, offerSeconds, maxCandidates, trialDays,
  graceDays, batchWindowMs, useRoadEta, supportPhone (defaults in `settings.defaults.ts`, cached 15 s). Dispatch reads
  radius, offer time, candidates, batch window and ETA source from here.
- **Admin API (`/v1/admin`, ADMIN role; phones in `ADMIN_PHONES`):** stats, live (online drivers + active trips), drivers
  (+ per-document KYC review, status), kyc queue, users (role, block/unblock → Redis `user:blocked:<id>` checked by the
  JWT guard), trips, passengers, plans, tickets, payments, cities / service-cells / zones / fares, announcements,
  settings, audit log, CSV exports (trips, drivers, payments). Every admin POST/PUT/PATCH/DELETE is written to `AuditLog`.
- **Public geo:** `GET /v1/cities`, `GET /v1/cities/:id/service-area` (cells + zones for the apps), `GET /v1/geo/check`,
  `GET /v1/announcements?audience=&cityId=`.
- **API prefix:** `/v1` (health endpoints unprefixed). Endpoint list: see README "Backend".
- **Database (Prisma):** User, EmergencyContact, SavedPlace, Place, Driver, KycDocument, Trip, Plan, Subscription,
  Payment, SupportTicket. Money in whole rupees (Int). Migrations in `apps/api/prisma/migrations`.
- **Redis keys:**

| Key | Purpose | TTL |
|---|---|---|
| `otp:code:<phone>`, `otp:attempts:<phone>`, `otp:sends:<phone>` | OTP + limits (5 sends / 15 min, 5 attempts) | 5–15 min |
| `h3:drv:<VEHICLE_KIND>:<cell>` | Online drivers per H3 cell (res 8) | – |
| `driver:cell:<driverId>` | The driver's current kind + cell (to move between sets) | – |
| `dispatch:pending`, `dispatch:lock` | Bookings waiting for the next batch; batch lock | – / batch window |
| `eta:<road\|est>:<cellA>:<cellB>` | ETA minutes between hex centres | 10 min |
| `driver:alive:<driverId>` | Heartbeat; stale drivers are skipped | 90 s |
| `driver:busy:<driverId>` | Active trip id | until trip ends |
| `user:blocked:<userId>` | Blocked by an admin (checked on every request) | until unblocked |
| `dispatch:<tripId>:queue`, `dispatch:<tripId>:offer` | Nearest-driver queue, current 15 s offer | 10 min / 15 s |
| `maps:ac:*`, `maps:pd:*`, `maps:rg:*`, `maps:rt:*` | Google response cache | 1 d / 30 d / 30 d / 6 h |

- **Dispatch (Uber-style, see owner ref "How Uber finds your driver"):**
  1. Drivers are indexed by H3 cell (res 8) in Redis sets `h3:drv:<kind>:<cell>`; no distance scan over all drivers.
  2. A booking waits in a batch window (`batchWindowMs`, default 2 s; Redis lock so one instance runs each batch).
  3. Candidates = pickup hexagon, then ring 1 (the six neighbours), ring 2… up to `searchRadiusKm`, stopping once
     enough drivers are found; busy and stale drivers are skipped.
  4. Candidates are ranked by **road ETA**, not straight-line distance (`EtaService`: Google Routes when
     `useRoadEta` and a key are set, else a 20 km/h × 1.3 estimate), cached per H3 cell pair for 10 min so all
     drivers in one hexagon share one lookup.
  5. The whole batch is assigned together (`assignBatch`: all trip–driver pairs by ETA, each driver to one rider),
     then each driver gets `offerSeconds` to accept; decline/timeout → next in that trip's queue → `NO_DRIVERS`.
- **Realtime (`/rt`):** connect with `auth: { token }`; rooms `user:<id>`, `driver:<id>`, `trip:<id>`. Events:
  `trip.offer`, `trip.updated`, `trip.location`, `trip.no_drivers`. Drivers stream `driver:location`.
- **Fares:** same engine as the apps. Distance: measured demo routes, then Google Routes distance (cached), then
  haversine × 1.3; duration uses 18 km/h so prices stay predictable.
- **Payments:** simulated (`Payment` rows with `providerRef sim_*`). Plug Razorpay Subscriptions / UPI Autopay into
  `SubscriptionsService.purchase`.
- **SMS:** OTP delivery is a stub (`OtpService.deliver`); plug MSG91 / Twilio there.

---

## 6b. Admin panel (apps/admin)

- **Stack:** Next.js 16 App Router (`src/`), React 19 Server Components, shadcn/ui + Tailwind v4, Recharts, Leaflet +
  h3-js. Brand tokens mapped onto the shadcn CSS variables in `src/app/globals.css` (primary coral-600 `#D84315`,
  foreground navy-900, muted navy-500, border `#E2E8F0`, background `#F8FAFC`, 12 px card radius); Poppins (headings)
  and Inter (body) via `next/font`. Light theme only.
- **Auth:** `/login` → phone (+91) → `POST /auth/otp` → 6-digit OTP (InputOTP) → `POST /auth/verify`; accepted only when
  `user.role === 'ADMIN'` (else "This number is not an admin"). The JWT is stored by a Server Action in the httpOnly,
  `SameSite=lax` cookie `rido_admin_token` (cookie life = JWT expiry) and is never readable from client JS.
  `src/proxy.ts` (Next 16 proxy, formerly middleware) redirects to `/login` when there is no unexpired ADMIN token;
  any API 401 clears the cookies (`/auth/signout`) and returns to `/login?expired=1`. Logout is in the user menu.
  Dev login: **9000000001**, any OTP except 000000.
- **Data access:** only from the server. `src/lib/api.ts` (server-only typed client, `API_URL` + Bearer token from the
  cookie, `cache: 'no-store'`), types in `src/lib/types.ts`. Mutations are Server Actions in
  `src/app/(panel)/actions.ts` (validate, call the API, `revalidatePath`, toast). Route handlers: `/api/live` (live-map
  polling, forwards the cookie), `/export/{trips|drivers|payments}` (streams the CSV exports), `/auth/signout`.
- **Pages (sidebar groups):** Overview: Dashboard (KPIs from `/admin/stats`, KYC queue, cities, blocked users, 7-day trips
  chart, pending KYC list, mini live map), Live (online drivers by vehicle colour, busy = coral ring, active trips,
  optional city hex overlay; polls every 10 s). Operations: Trips (+ detail: route, fare breakdown, timeline, parcel,
  tickets; OTP hidden), Drivers (+ detail: profile, vehicle, UPI, KYC verify/reject with reason, approve / hold /
  reactivate, subscriptions, payments, recent trips), KYC queue (tabs by status, badge count in the sidebar),
  Passengers, Users (role tabs, blocked filter; detail: role change, block with reason / unblock, contacts, saved places,
  trips, tickets), Support (status changes). Configuration: Zones (`/cities`: list, add city with map picker;
  `/cities/[id]`: service-area painter with paint / erase / circle fill / clear / undo-redo and faint viewport hexes,
  zones editor painted on the map with outside-area warning, per-city fares with preview calculator, city settings and
  delete), Plans (price + active per vehicle × period), Settings (pricing, dispatch, plans, support phone),
  Announcements. Finance: Payments. System: Audit log (expandable JSON). Every page has `loading.tsx` skeletons,
  `error.tsx` (retry) and empty states.
- **Maps:** Leaflet is loaded with `next/dynamic({ ssr: false })` (`src/components/map/lazy.tsx`); hexagons are drawn
  with `cellToBoundary` in an imperative layer that only diffs changed cells (1,500+ cells stay smooth). NO_SERVICE
  zones are hatched red (SVG pattern). Viewport hexes are only drawn below ~5,000 cells (zoom in to paint new ones).
- **Monorepo:** `apps/admin/turbo.json` extends the root pipeline with the admin's inputs (`src/**`, `test/**`);
  `analyze` = `next typegen && tsc --noEmit && eslint` (generated `src/components/ui/**` is not linted).

---

## 7. Maps and location

| Need | Service | Called from | When |
|---|---|---|---|
| Show the map | Maps SDK for Android (free) | apps | always, when key set |
| Search places | Places Autocomplete (New) + Place Details | API (`/places/autocomplete`, `/places/details`) and app | per search session (session token), ≥ 3 chars, debounced |
| Pin → address | Geocoding API | API (`/places/reverse`) and app | when the pin stops moving; cached on an ~11 m grid |
| Route line / distance | Routes API (traffic-unaware) | API (`/maps/route`, fares) and app | once per trip leg; cached on a ~100 m grid |
| Live tracking | Driver GPS over Socket.IO | driver app → API → passenger | every few seconds, **no Google calls** |

**Cost rules (do not break):**
1. Never call Directions/Routes on a timer during a trip; ETA comes from the driver's GPS progress along the stored polyline.
2. Use autocomplete session tokens; end each session with one Place Details call.
3. Request only the fields needed (FieldMask) to stay on Essentials SKUs.
4. Cache geocodes and routes in Redis (API) and in memory (apps).
5. At scale (~1,000 rides/day), move to Google Mobility Services (per-trip pricing) or self-hosted OSRM/Valhalla.

Fallbacks: no key or offline → CARTO tiles (flutter_map), OSRM public router, seeded places, haversine distances.

Three keys (details and restrictions in `docs/GOOGLE_MAPS_SETUP.md`): key 1 map SDK (Android-restricted), key 2
server (IP-restricted), key 3 app web services (API-restricted only; the apps' `dart:io` calls can't send Android
signature headers, so remove key 3 once the apps call the backend). Debug SHA-1 on the dev machine:
`B5:C9:F1:A3:D4:2E:20:F7:24:2A:F7:94:54:CC:26:36:3B:4D:52:99`.

App-side implementation: `packages/rido_data/lib/src/maps/` (config, HTTP helper, Places client, polyline codec),
`RoadRouter` (Google → OSRM → curved line), `packages/rido_ui/lib/src/widgets/rido_map_google.dart` (GoogleMap engine,
markers rendered to bitmaps, light style in `rido_map_style.dart`). `RidoMap` takes a `RidoMapController` and reports
`RidoCamera`. Place Details asks for Essentials fields only (`id,formattedAddress,location`); the app keeps the
suggestion's name.

---

## 8. Testing and quality

| Package | Checks |
|---|---|
| rido_data | fare engine unit tests (₹38/72/145, ₹49/180/420, lines add up) |
| rido_ui | formatter tests |
| passenger / driver | every Design gallery frame at 360 and 430 px, main-path flow tests (fast mode, fake time) |
| api | unit (fare engine, transitions, subscriptions, maps service, polyline) + e2e (full ride lifecycle, fallbacks) |
| admin | Vitest unit: ₹ Indian formatting, IST dates, paging/URL builder, API URL + error helpers, safe post-login redirect, JWT role/expiry check, fare preview = API engine (₹38 demo trip), H3 circle fill/undo, settings validation |

`npm run check` must pass with zero analyzer issues before merging.

---

## 9. Android build notes

- Impeller runs on **OpenGL ES** (`io.flutter.embedding.android.ImpellerBackend=opengles` in both manifests): the
  Vulkan backend lagged frames on MediaTek/Mali devices (bottom sheet looked stuck).
- Permissions: INTERNET, ACCESS_FINE_LOCATION, ACCESS_COARSE_LOCATION (passenger).
- Launcher icons and native splash generated from the brand board (`res/mipmap-*`, `drawable-nodpi/splash_logo.png`).
- Release signing is not configured yet (uses debug keys). Add `android/key.properties` (git-ignored) before store release.

---

## 10. Not done yet / next steps

| Item | Notes |
|---|---|
| Apps → API | Apps still use mock repositories (`rido_data`); swap in HTTP repositories via Riverpod overrides |
| CI | Add GitHub Actions: `npm ci`, `npm run check`, API e2e with service containers, APK build artifacts |
| Hosting | AWS ap-south-1 (Mumbai): ECS Fargate or one EC2 + Docker, RDS Postgres, ElastiCache Redis |
| Secrets | AWS Secrets Manager / SSM for `JWT_SECRET`, Google keys, DB password |
| Observability | Structured logs → CloudWatch; health checks already exposed |
| Payments | Razorpay Subscriptions (UPI Autopay mandates) |
| SMS | MSG91 / Twilio for OTP |
| Admin panel | **Done (25 Sep 2026)**: `apps/admin`, all modules above. Follow-ups: KYC file previews need uploads (`fileUrl` is empty in seed); no 2FA/IP allow-list for admins yet |
| Google Maps on device | Verify the Google engine on a real phone with keys (never run with a key yet) |
| Google logo padding | Set `GoogleMap.padding` so bottom sheets don't cover the Google logo (required by the terms) |
| Two-wheeler routing | `RouteTravelMode.twoWheeler` exists but callers pass DRIVE; pass it for bike legs |
| Google search in pickers | P-23b saved-place editor and parcel place picker still list seed places only |
| H3 | See plan below |

---

## H3 plan (owner recommendation #1)

[H3](https://h3geo.org) (Uber's hexagonal grid) fits three jobs. It is **not implemented yet**.

| Use | How | Replaces |
|---|---|---|
| Driver–passenger matching | **Done (25 Sep 2026):** drivers indexed at res 8; pickup hex then rings outward; ranked by road ETA per hex pair; batched assignment | Redis GEOSEARCH radius (removed) |
| Demand zones and surge | Count requests and online drivers per resolution-8 hex every minute; high demand/supply ratio → "High demand" zones (D-14) and the ≤1.5x multiplier | Hard-coded demand circles in seed |
| ETA | Historical average speed per hex pair and hour (from completed trips) → ETA without calling Routes | 18 km/h constant |

Implementation sketch:
- API: `h3-js` package; store `h3r9` on the driver heartbeat (Redis set per hex, e.g. `h3:9:<cell>:<vehicleKind>`)
  and on each trip (pickup/drop cells) in Postgres for analytics.
- Analytics: nightly job aggregating trips per hex/hour into a `hex_stats` table.
- Apps: optional `h3_flutter` to draw demand hexagons on the driver map.

Status (25 Sep 2026): **service areas and zones are live on H3** (cities, SURGE/DEMAND/NO_SERVICE/PICKUP_POINT zones,
per-city fares; admin editor in the admin panel). Still to do: driver matching by hex rings, demand/supply stats per hex,
and hex-based ETA; GEOSEARCH remains the dispatcher until the pilot has trip data (month 2–3).

Fixed 25 Sep 2026: `/admin/users?role=&blocked=` (added to `ListQueryDto`) and the API image seed crash (`h3.util.ts`
copied into the runtime image).

Gotcha learned: Prisma queries are lazy; `void prisma.x.create(...)` never runs. Always `await` or attach `.catch()`.
