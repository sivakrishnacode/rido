# Rido: Technology & DevOps

Single technical reference for the Rido monorepo. Keep it current: update this file whenever the stack, services,
environment variables, commands or infrastructure change.

Last updated: 25 Sep 2026

---

## Owner recommendations

Notes from the owner. Each item gets a status and a plan once reviewed.

| # | Recommendation | Status | Plan |
|---|---|---|---|
| 1 | https://h3geo.org - opensource for geo data anlysing and driver - user match, ETA finding and more | **Done (25 Sep 2026):** service areas + zones, H3 dispatch (rings + ETA + batches), heatmaps, live demand/supply surge with k-ring smoothing, learned hex-to-hex ETA, compaction. Refs: Uber H3 blog, "How Uber finds your driver" | See [H3 plan](#h3-plan-owner-recommendation-1) |

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
| Admin maps | Google Maps JavaScript API via `@vis.gl/react-google-maps` (JSON-styled roadmap + satellite), H3 hexagons on `google.maps.Data` layers with h3-js | react-google-maps 1.10, h3-js 4.5 | `apps/admin/src/components/map`, `src/lib/hex.ts` |
| Tests | Flutter test (widget + flow), Vitest 4 (API unit + e2e, admin unit) | | `apps/*/test`, `packages/*/test` |
| Lint | `flutter analyze` (flutter_lints), oxlint + `tsc --noEmit` (API), ESLint 9 (`eslint-config-next`) + `tsc --noEmit` (admin) | | per package |
| Containers | Docker, Docker Compose | Docker 29, Compose 5 | `docker-compose.yml`, `apps/api/Dockerfile`, `apps/admin/Dockerfile` |

---

## 2. Repository layout

```
apps/
  api/                @rido/api        NestJS backend (Prisma, Redis, Socket.IO)
  admin/              @rido/admin      Next.js admin panel (shadcn/ui, Google Maps + H3 editor, heatmap), port 3001
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
| `npm run test:e2e -w @rido/api` | API end-to-end tests on an isolated `rido_test` database + Redis DB 1 (migrated and seeded each run; dev data untouched) |
| `npm run seed:demo-trips -w @rido/api [-- --clear]` | Add (or remove) ~2,000 demo trips for heatmaps and dashboards |
| `npm run seed:demo-people -w @rido/api [-- --clear]` | Add (or remove) 40 passengers, 32 drivers (KYC, subscriptions, payments) and 12 tickets; run after demo trips, which it spreads across them |
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
| `NEXT_PUBLIC_GOOGLE_MAPS_BROWSER_KEY` | admin (build time, client bundle) | empty | browser key for the **Maps JavaScript API** (must be enabled on the key). Local dev: `apps/admin/.env.local` (git-ignored, template `apps/admin/.env.example`). Docker: root `.env` `GOOGLE_MAPS_BROWSER_KEY` → build arg. Currently the `rido-app-services` key; restrict to HTTP referrers later (`rido-admin-web`) |

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
- **Heatmaps:** trips store `pickupCell` / `dropCell` (H3 res 8, indexed). `GET /v1/admin/heatmap?metric=pickups|drops|unmet|fares
  &from&to&kind&vehicleKind&hourFrom&hourTo&resolution` aggregates per cell in SQL (hour filter in IST; resolution < 8
  rolls up to parent hexes). Demo data: `npm run seed:demo-trips -w @rido/api` (~2,000 trips, ids `demo_…`;
  `-- --clear` removes them).
- **Public geo:** `GET /v1/cities`, `GET /v1/cities/:id/service-area` (cells + zones for the apps), `GET /v1/geo/check`,
  `GET /v1/announcements?audience=&cityId=`.
- **API prefix:** `/v1` (health endpoints unprefixed). Endpoint list: see README "Backend".
- **App APIs added 26 Sep 2026 (mobile go-live):**
  - `GET /trips/active` (the caller's unfinished trip, to restore either app after a restart), `GET /trips/offer`
    (driver: the request currently offered, for when the socket missed `trip.offer`).
  - `GET|POST /trips/:id/messages` in-trip chat (Redis list `trip:chat:<id>`, 24 h, ≤ 200 messages; pushed as
    `trip.message` on the trip room).
  - Trips include `driver.user` and `passenger` (name, phone) for both sides; the **OTP is hidden from drivers** in
    offers, trip reads and history.
  - `trip.offer` payload: `{ trip, passenger: {name, phone}, pickupKm, pickupEtaMin, expiresInSeconds }`.
  - `PATCH /drivers/me` (name, gender, work type, vehicle model/colour, plate, UPI), `GET /drivers/me/earnings?period=today|week|month`
    (today in 2-hour buckets, 7 days, 4 weeks; commission saved = 30 % of fares; online hours from Redis
    `driver:online_since:<id>` / `driver:online_secs:<id>:<IST day>`, 40 days).
  - `POST /drivers/me/documents/:type` is **multipart** (`file`: JPG/PNG/WebP/PDF ≤ 8 MB) → **S3**
    `s3://rido-uploads-786020471552/kyc/<uuid>.<ext>` when `S3_BUCKET` is set (production), else local disk
    (`UPLOAD_DIR`, Docker volume `uploads`, dev) → `KycDocument.fileUrl` = file name. Admins read it via
    `GET /v1/admin/files/:name` (streams from S3; files saved on disk before the switch are still found), proxied by
    the admin panel at `/files/:name` (never public). `FileStorageService` in `core/storage`.
  - `GET /subscriptions/me/payments`, `POST /subscriptions/me/autopay {upiApp}` (Autopay during the trial).
  - **Arrival / drop check:** `POST /trips/:id/arrived` and `/complete` take `{lat, lng, farReason}` (position
    defaults to the last GPS fix). Farther than `arrivalRadiusM` (250 m) from the pickup or `dropRadiusM` (400 m) from
    the drop without a reason → **422 `TOO_FAR`** `{message, details: {stop, distanceM, radiusM, reasons}}`; with a
    reason it proceeds and stores `arrivedDistanceM` / `arrivedFarReason` / `endDistanceM` / `endFarReason` on the trip
    (admin trip page shows them). Parcels: the delivery OTP is checked first. Unknown position → not enforced.
    Errors may carry `code` / `details` (global filter); apps read them as `ApiException.code` / `.tooFar`.
  - Global JWT/roles guards now skip non-HTTP contexts: sockets authenticate on connect. (Before this, `trip:join` and
    `driver:location` crashed in the guard, so live tracking never reached passengers.)
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
| `dispatch:<tripId>:queue`, `dispatch:<tripId>:offer`, `dispatch:driver:<driverId>:offer` | Nearest-driver queue, current 15 s offer (both directions) | 10 min / 15 s |
| `trip:chat:<tripId>` | In-trip chat messages | 24 h |
| `driver:online_since:<id>`, `driver:online_secs:<id>:<day>` | Online session start; online seconds per IST day | – / 40 d |
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
     then each driver gets `offerSeconds` to accept; decline/timeout → next in that trip's queue.
  6. **Out of candidates (26 Sep 2026):** search again every 4 s. A driver who let the offer **time out** can be
     offered it again (e.g. the only driver around); one who **declined** is excluded for that trip
     (`dispatch:<id>:declined`). `NO_DRIVERS` after 90 s if any driver was offered it, after 30 s if nobody was
     nearby, or at once when a fresh search finds only drivers who declined. A sweep every 15 s re-queues or ends
     SEARCHING trips that lost their timers (restarts). Fix: the offer key now outlives the offer timer by 5 s
     (before, both expired together, the timeout handler saw no offer and the trip stayed SEARCHING forever).
- **Realtime (`/rt`):** connect with `auth: { token }`; rooms `user:<id>`, `driver:<id>`, `trip:<id>`. Events:
  `trip.offer`, `trip.updated`, `trip.location`, `trip.message`, `trip.no_drivers`. Drivers stream `driver:location`;
  clients `trip:join {tripId}` (participants only).
- **Fares:** same engine as the apps. Distance: measured demo routes, then Google Routes distance (cached), then
  haversine × 1.3; duration uses 18 km/h so prices stay predictable.
- **Payments:** simulated (`Payment` rows with `providerRef sim_*`). Plug Razorpay Subscriptions / UPI Autopay into
  `SubscriptionsService.purchase`.
- **SMS:** OTP delivery is a stub (`OtpService.deliver`); plug MSG91 / Twilio there.

---

## 6b. Admin panel (apps/admin)

- **Stack:** Next.js 16 App Router (`src/`), React 19 Server Components, shadcn/ui + Tailwind v4, Recharts, Google Maps
  JavaScript API (`@vis.gl/react-google-maps`) + h3-js. Brand tokens mapped onto the shadcn CSS variables in `src/app/globals.css` (primary coral-600 `#D84315`,
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
  `src/app/(panel)/actions.ts` (validate, call the API, `revalidatePath`, toast). Route handlers (all check the admin
  cookie): `/api/live` (live-map polling), `/api/heatmap` (heatmap filters), `/api/places` + `/api/places/[id]` (map
  search over the API's Places Autocomplete with the server key and Redis cache: no client Places billing),
  `/api/demand` (live demand snapshot, `?refresh=true` recomputes), `/export/{trips|drivers|payments}` (streams the CSV
  exports), `/auth/signout`.
- **Pages (sidebar groups):** Overview: Dashboard (KPIs from `/admin/stats`, KYC queue, cities, blocked users, 7-day trips
  chart, pending KYC list, "Surging now" count → Live, Hotspots = top 5 pickup hexes named by reverse geocode (cached a
  day), mini live map), Live (online drivers by vehicle colour, busy = coral ring, names on hover, active trips,
  optional city hex overlay and demand heat; polls every 10 s; plus the **Demand vs supply** layer below), Heatmap
  (below). Operations: Trips (+ detail: route, fare breakdown, timeline, parcel,
  tickets; OTP hidden), Drivers (+ detail: profile, vehicle, UPI, KYC verify/reject with reason, approve / hold /
  reactivate, subscriptions, payments, recent trips), KYC queue (tabs by status, badge count in the sidebar),
  Passengers, Users (role tabs, blocked filter; detail: role change, block with reason / unblock, contacts, saved places,
  trips, tickets), Support (status changes). Configuration: Zones (`/cities`: list, add city with map picker;
  `/cities/[id]`: service-area painter with paint / erase / circle fill / clear / undo-redo and faint viewport hexes,
  zones editor painted on the map with outside-area warning, per-city fares with preview calculator, city settings and
  delete), Plans (price + active per vehicle × period), Settings (pricing, dispatch, plans, support phone),
  Announcements. Finance: Payments. System: Audit log (expandable JSON). Every page has `loading.tsx` skeletons,
  `error.tsx` (retry) and empty states.
- **Maps (Google Maps JavaScript API):** `src/components/map/google/rido-map.tsx` wraps `APIProvider` (`language=en`,
  `region=IN`) + `Map` with a light JSON style (land `#EEF0F3`, white roads, water `#D5E5F1`, parks `#DDEBD8`, POIs,
  transit and local-road labels off, navy-500 labels with a white halo; neighbourhood names only at zoom ≥ 14) and a
  Map / Satellite (hybrid) toggle. No Map ID (JSON styles can't be combined with one), so markers are `Data` points /
  symbols, not AdvancedMarker. Hexagons are GeoJSON features (from `cellToBoundary`, [lng, lat]) on one
  `google.maps.Data` layer per layer, diffed so painting touches only changed cells. If the key is missing or Google
  calls `gm_authFailure` (e.g. **Maps JavaScript API not enabled**), the map area shows "Enable the Maps JavaScript API
  for this key in Google Cloud → APIs & Services → Library". Google adds local-script (Tamil/Malayalam) names on India
  tiles for every language/region combination tried, so clutter is reduced in the style instead.
- **Zones editor (`/cities/[id]`, Service area and Zones tabs; `src/components/map/editor/`):**
  - Find: search box on the map (debounced 300 ms, ≥ 3 characters, one session token per search, then details) → flies
    to zoom 15 with a marker; "Add area around here" / "Remove" fills a circle of the chosen radius there.
  - Tools: Paint / Erase with a 1, 7, 19 or 37-hex brush (k-rings 0–3), click-drag painting with pointer events (mouse,
    touch, pen; map panning is off while painting, the wheel still zooms) and a hover preview outlining exactly the
    hexes that will change (coral = add, red = erase) with a +n / −n count. Draw area: click points, double-click or
    click the first point to close, then "Add to" / "Remove from" (h3 `polygonToCells` at the city resolution;
    estimated first and refused above 20,000 hexes). Circle: click a centre, pick a radius. Undo / redo for every stroke.
  - Layers: Service area / Zones / zone labels / hex grid (outlines only, zoom ≥ 13, viewport only) / demand heat
    (pickups, drops, unmet, fares; last 30 days, drawn under the other layers). Fit to service area (outlier-trimmed
    bounds, so a stray hex doesn't zoom out the map), fullscreen, map height = viewport minus header (min 600 px).
  - Zone labels: short pill (name, coloured dot, "1.2×" for surge) at the centre of each zone's largest cluster,
    shown from zoom 13 and skipped when they'd overlap a higher-priority label (active and larger zones first); full
    name, kind and multiplier on hover.
  - Zone cells outside the service area get an amber outline and a "remove outside hexagons" action.
  - Shortcuts (help popover on the map): **P** paint, **E** erase, **D** draw area, **C** circle, **H** or hold
    **Space** pan, **[** / **]** brush size, **Esc** cancel, **Ctrl+Z** / **Ctrl+Shift+Z** undo / redo.
- **Demand vs supply (Live page, on by default):** res-7 hexes from `GET /v1/admin/demand` (recomputed by the API every
  60 s; the page polls every 30 s, "Refresh" forces `?refresh=true`): busy = amber, high = coral / red, normal cells
  hidden; "1.2×" pills on surging cells with the same collision rule as zone labels; hover shows bookings, free drivers,
  ratio and multiplier. Side card "Surging now" lists cells by multiplier with fly-to.
- **Settings (`/settings`):** renders every key `GET /v1/admin/settings` returns: "Pricing & surge"
  (dynamicSurgeEnabled, surgeSensitivity, demandWindowMin, surgeMinRequests, maxMultiplier, currentMultiplier, with the
  formula and a live example: ratio 3 → 1 + 0.1 × 2 = 1.2×), "Dispatch & ETA" (batchWindowMs, useRoadEta,
  historicalEtaMinTrips, searchRadiusKm, offerSeconds, maxCandidates), Driver plans, Support, and any new key in
  "Other" (typed from the API value). Only changed keys are sent; values are validated client + server side.
- **Travel speeds (`/travel-speeds`, System):** `GET /v1/admin/hex-stats?res=9|8|7&hour=&sort=busiest|slowest|fastest&used=true`.
  Tabs for hex size (street res 9 / neighbourhood res 8, default / district res 7, with row counts); filters for IST hour,
  sort and "only pairs used for ETAs". KPIs: **ETA error** (recent 14 days of finished trips replayed through the learned
  speeds: MAPE, ± minutes, bias; in-sample, so an upper bound), **trips with a learned ETA** (coverage), **rush-hour
  slowdown** (8–10 am / 5–8 pm vs rest, time-weighted), rows at this size + "Rebuild now". Speed-by-hour chart over all
  rows at the size (rush hours darker, trips line, whole-day average), a "Where ETAs come from" table (street / neighbourhood /
  district pair, all-day average, fallback: share, ± min, % error), top 50 pairs (place names for every hex via cached reverse
  geocode; "rush", "used", **vs hour avg** %), and a map with two modes: selected pair, or **slow areas** (speed of trips
  leaving each hex on the heat ramp, hour filter applies).
- **Heatmap (`/heatmap`):** H3 choropleth of `GET /v1/admin/heatmap` (metric pickups / drops / unmet demand / fares ₹,
  date presets Today / 7 / 30 days / custom, hour-of-day range with Morning 7–10 and Evening 17–20 presets, ride/parcel,
  vehicle, resolution Street 8 / Area 7 / District 6), colour-blind-safe yellow → coral → deep red ramp at 0.65 opacity,
  legend, hover tooltip (value, share, rank), Top 10 list (fly to), totals and a 3-hour bucket chart. Select hexes (click
  / Shift-click / "Select top 10") → **Create zone** (SURGE or DEMAND, city detected from the cells, converted to the
  city's resolution) or **Add to service area**; unmet demand outside every service area has a dashed amber outline.
  Filter changes are debounced 300 ms.
- **Monorepo:** `apps/admin/turbo.json` extends the root pipeline with the admin's inputs (`src/**`, `test/**`);
  `analyze` = `next typegen && tsc --noEmit && eslint` (generated `src/components/ui/**` is not linted).

---

## 7. Maps and location

| Need | Service | Called from | When |
|---|---|---|---|
| Show the map | Maps SDK for Android (free) | apps | always, when key set |
| Admin maps | Maps JavaScript API (Dynamic Maps, billed per map load) | admin panel browser (`NEXT_PUBLIC_GOOGLE_MAPS_BROWSER_KEY`) | each page with a map; search goes through the API, not the client Places library |
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

## 7a0. Driver demand map (hex + nested hex)

- **API:** public `GET /v1/demand/hotspots` (`DriverMapService`, Redis-cached 60 s, key `drivermap:v2`): up to 30 res-7
  hexes (≈5 km²) ranked by live demand (distinct riders in the demand window ×3) + bookings in the last hour (×2) +
  the usual pickups at this IST hour ±1 over the last 4 weeks (weekly average). Level: `high` (surging, or ≥ 60 % of the
  busiest), `busy` (≥ 30 % or live busy), `some`. Each hotspot carries its outline and its busy res-8 children
  (`nested`, score 0–1 within the hotspot) like H3's hex-in-hex grid; plus `serviceArea` = each city's service cells
  merged into outer rings (`cellsToMultiPolygon`). No rider counts are exposed.
- **Driver app:** `demandMapProvider` (refresh every 2 min while Home shows it, live mode only) → `demand_layer.dart`:
  service-area edge at zoom ≤ 12.8, demand hexes from 10.5 (coral high / amber busy / yellow some), nested hexes from
  13.2 shaded by their share, "High demand" (· surge) labels on the top 4. Hidden during a job.
- **rido_ui:** `RidoMap.polygons` (`MapPolygon` with fill, stroke, zIndex and a zoom range) on both engines.

## 7a. Device location in the apps

- **Maps follow position changes:** the Google engine now animates to a new `RidoMap.center` (it only read the
  initial camera, so the driver map stayed on the first position); following pauses 15 s after the user pans or
  zooms (only camera moves while a finger is on the map count). Driver offline: last known fix (fused, then
  LocationManager) + a medium-accuracy preview stream (no service, nothing uploaded). Going online uses a position
  under 2 min old instead of waiting for a fresh precise fix (indoors that timed out).
- **Always the real position (live):** both apps read the last known fix at once, then a fresh one. Passenger: the
  pickup and map are the phone's location even outside the service area (banner "Rido isn't in your area yet"; the API
  refuses bookings there). Driver: the car marker follows the phone while offline too (nothing uploaded); with no fix
  yet the map shows the city without a made-up car. The Gandhipuram / seed home points are for mock mode only.
- **Permission asked on every visit until given:** on opening Home and whenever the user comes back to the app
  (`AppLifecycleListener.onRestart`, so closing the dialog doesn't re-trigger it). `LocationAccess` (granted,
  serviceOff, denied, deniedForever) drives a banner on Home explaining why location is needed; its button asks again,
  opens location settings (GPS off) or the app's settings page (after "Don't allow" twice).

## 7b. Apps ↔ API (packages/rido_data/lib/src/api)

- **Base URL:** `kApiBaseUrl` = `--dart-define=RIDO_API_URL` (default `http://65.0.233.253:3000/v1`, the AWS staging
  server). `--dart-define=RIDO_LIVE_API=false` runs the apps on seed data + the trip simulator (widget tests and the
  design gallery always do: they don't apply the overrides).
- **Wiring:** each app's `main()` loads `ApiSession` (token + driver id in SharedPreferences), creates `ApiClient` and runs
  `ProviderScope(overrides: liveApiOverrides(api))`, which swaps every repository provider for its `Api*Repository` and
  sets `isLiveApiProvider`. Screens don't change; flow controllers branch on `isLiveApiProvider`.
- **HTTP:** `ApiClient` (package:http, 20 s timeout). Network errors → `OfflineException` (screens' offline state); API
  errors → `ApiException(status, message)` with the API's user-facing message; 401 clears the session and fires
  `onUnauthorized` (apps go to sign-in).
- **Realtime:** `RealtimeClient` (socket_io_client, websocket, auto-reconnect, re-joins trip rooms). `LiveTrips`
  (passenger: book, status, driver GPS, chat, cancel, rate, restore) and `LiveJobs` (driver: online/offline, offers,
  accept → arrived → start(OTP) → complete, GPS over the socket with an HTTP heartbeat fallback, chat, restore).
- **Routes:** `RoadRouter.backend = backendRouter(api)` → `POST /v1/maps/route` (Google on the server, Redis-cached,
  two-wheeler for bikes via `travelModeFor`), then OSRM. The apps no longer need the app-side Google web-services key
  (key 3) in live mode; places search also goes through the API.
- **Mapping:** `api_mappers.dart` (API enums `GOODS_BIKE` ↔ app `goodsBike`; NO_DRIVERS folds into cancelled; parcel
  details stored as JSON on the trip; the ride OTP doubles as the parcel delivery OTP). Tests: `test/api_mappers_test.dart`.
- **Android:** cleartext HTTP is allowed only for the staging IP (`res/xml/network_security_config.xml`); switch to
  HTTPS and remove it once there's a domain.

## 7c. Push notifications (FCM)

- **Firebase project `rido-93cd3`** (Spark, free). Android apps `com.rido.passenger` and `com.rido.driver`; their
  `android/app/google-services.json` is per machine and git-ignored (originals in `~/rido-secrets/`). Without the file
  the apps build and run without push (the Google Services Gradle plugin is only applied when it exists).
- **API:** `NotificationsModule` (global). `PushService` = firebase-admin (HTTP v1) with the service account from
  `FIREBASE_SERVICE_ACCOUNT_B64` (base64 JSON in the server's `.env`, mode 600; empty = push off, logged). Device
  tokens in `DeviceToken` (token PK, userId, app PASSENGER|DRIVER); `POST /me/devices {token, app}`,
  `DELETE /me/devices/:token`; tokens FCM reports as dead are deleted. Pushes never fail the request.
- **What is sent (`NotifierService`):**

| Event | To | Channel |
|---|---|---|
| Driver assigned (with OTP), arrived, ride started / parcel picked up, completed / delivered, no drivers | Passenger | `trip_updates` |
| Cancelled by the driver | Passenger | `trip_updates` |
| New request (high priority, TTL = offer seconds, so a late push never shows) | Driver | `ride_requests` |
| Cancelled by the passenger | Driver | `trip_updates` |
| Chat message | The other side | `chat` |
| KYC document rejected (with reason) / all verified ("You're approved!") | Driver | `account` |
| Admin announcement (active, already started) | Topic `all`, `passengers` or `drivers` | `announcements` |

- **Apps (`RidoPush` in rido_data):** Firebase init in `main()` (live mode), Android channels with the same ids,
  notification permission (Android 13+) after sign-in, token registered whenever the session token changes (incl.
  driver sign-up) or FCM rotates it, topics subscribed; sign-out unsubscribes and deletes the token. In the
  background Android shows the notification itself; in the foreground it's shown locally unless the app already shows
  it (passenger: trip updates; driver: requests and trip updates). Taps: passenger trip/chat → reopen the active trip;
  driver request/trip/chat → recover the offer / job; KYC → start route.
- **Test:** install both APKs, sign in, then Admin → Announcements → create one for "All" → it arrives on both phones.

---

## 7d. Driver app in the background (apps/driver/lib/overlay)

- **Floating bubble:** while online and the app is in the background, a draggable Rido bubble is drawn over other
  apps (`flutter_overlay_window`, SYSTEM_ALERT_WINDOW, asked once with an explanation when going online; the app
  works without it). Tap → back to Rido. Hidden in the foreground, offline or after sign-out.
  The bubble is a foreground service, so Android requires a notification: `MainActivity` pre-creates the plugin's
  channel (`"Overlay Channel"`) at IMPORTANCE_MIN so it stays silent and collapsed (a channel keeps its first
  importance; phones that already had the plugin's default channel need a reinstall). `drawable/notification_icon`
  overrides the plugin's icon with the Rido mark.
- **Patched plugin:** `packages/flutter_overlay_window` is a vendored copy of 0.5.0 (`dependency_overrides` in the driver
  pubspec) with fixes listed in its `RIDO_PATCHES.md`: no sticky restarts (orphan bubbles), no self-stop after
  re-showing, native tap-to-open with a drag slop (drags opened the app; taps went through the app's engine),
  `closeOverlay` always stops and always answers (a missing answer froze the bubble queue), broadcast listener.
  `BackgroundOffers` asks the plugin whether the window is really up, shows the bubble 0.6 s after going to the
  background, re-checks 0.8 s / 2.5 s after coming back, and bounds every platform call (tests:
  `test/background_offers_test.dart` with an async fake of the native side).
- **Engine outlives the screen:** `MainActivity.provideFlutterEngine` returns one engine cached for the process
  (`FlutterEngineCache`, id `rido_main`) and `shouldDestroyEngineWithHost` is false. Android may destroy a background
  app's Activity while the process lives on (the online GPS service keeps it); the default FlutterActivity destroyed
  its engine too, so the bubble / reopening started the app from scratch and the "start offline" rule took the
  driver offline. `AppLifecycleState.detached` counts as background for the bubble.
- **One app instance:** `MainActivity` is `singleTask` with the default task affinity, and "open app" (bubble tap,
  after Accept) moves the existing task to the front (`ActivityManager.appTasks`). With the template's
  `taskAffinity=""` every such launch started a second copy (splash again, two engines, overlay messages to the wrong
  one: Accept spinning forever).
- **Verified on a Nothing Phone (1), Android 16, 26 Sep 2026** (adb): online → Home → bubble; tap → same app, still
  online; Home → bubble again; launcher → no restart; request while minimised → full-screen card; Accept → job screen
  in front (DRIVER_ASSIGNED); Decline → bubble + NO_DRIVERS; timeout → bubble, re-offer → card again.
- **Bugs found on the device and fixed:** bubble parked off screen (x = -186 px) because a minimised app reported a
  1×1 screen (overlay measures itself, plugin clamps on screen); the FCM background engine took over the overlay's
  message channel so Accept went nowhere (plugin: only the Activity engine owns it); the card height used a guessed
  844 dp (now MATCH_PARENT); FLAG_INSISTENT rang non-stop (now one ring per request, `onlyAlertOnce`).
- **Request card safety:** Decline / timeout close the card at once; Accept gives up after 12 s ("Rido didn't
  respond", opens the app); an error closes the card after 2.5 s; a ✕ always returns to the bubble and opens Rido.
- **Never online by itself:** the app always starts offline; if the API still has the driver online (app killed while
  online) it is set offline. Only an unfinished job restores the online state. A trip that timed out on the phone
  can be offered again by dispatch (only accepted / declined trips are ignored afterwards).
- **Full-screen request:** a `trip.offer` arriving in the background (the socket stays up thanks to the GPS
  foreground service) expands the overlay into a full-screen card (fare, pickup → drop, distance / ETA, customer,
  server countdown, Accept / Decline) with a ringing high-priority notification. The overlay runs in its own engine
  (`overlayMain`) and only exchanges messages (`overlay_protocol.dart`); API calls stay in the main isolate. Accept →
  job screen and the app comes to the front; Decline / timeout → back to the bubble.
- **Fallback:** without the overlay permission, or if the process was killed, the `ride_requests` notification uses a
  full-screen intent (USE_FULL_SCREEN_INTENT; Android 14+ checks `canUseFullScreenIntent` via `MainActivity` and
  links to the settings page once). Opening it shows the request card (`currentOffer`).
- **Location check UI:** `too_far_sheet.dart` (`runWithFarCheck`) wraps Arrived / End ride / Reached pickup /
  Complete delivery: on `TOO_FAR` it shows the distance, reason chips + "Other", Navigate, and "Continue anyway".
- **Uploads:** KYC photos are resized to ≤1600 px at quality 80 before upload.

## 7e. Passenger onboarding and sign-in (apps/passenger/lib/features/onboarding)

- **Intro (P-02)**: a tinted scene panel that blends between slide colours while swiping, parallax scenes that idle
  on a loop (road scrolls, vehicles bob, chips float, sparkles twinkle), text that rises in, and a round "next"
  button with a progress ring that stretches into "Get started" on the last slide.
- **Sign-in steps (P-03 number → P-04 verify → P-05 you)** share `widgets/sign_in_step.dart`: a scooter rides a
  dashed road to the current stop, each step has an animated badge (buzzing phone, bobbing SMS, waving hand), and
  heading and fields rise in, one after another. The button pops when the form becomes valid. Confetti fires when sign-in finishes
  (returning passenger on OTP, new passenger on P-05) before the next screen (~0.8 s). The three routes cross-fade
  (`_signInStep` in `app_router.dart`) so they read as one screen. P-05 in edit mode keeps the plain layout.
- All looping or decorative motion stops when Android "Remove animations" is on (`MediaQuery.disableAnimations`).

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

## 9b. AWS deployment (single EC2, low cost)

Everything (Postgres, Redis, API, admin) runs with Docker Compose on one EC2 instance. No domain yet, so it's plain HTTP on the IP.

| Item | Value |
|---|---|
| Account / region | `786020471552` / ap-south-1 (Mumbai), AWS CLI profile `rido` (IAM user `rido-deployer`, `AmazonEC2FullAccess` only) |
| Instance | `i-0f90806819ce574cd` (`rido-server`), t3.small (free-tier eligible), Ubuntu 24.04, 20 GB gp3, 2 GB swap |
| Public IP | Elastic IP **65.0.233.253**: API `http://65.0.233.253:3000/v1`, admin `http://65.0.233.253:3001` |
| Security group | `sg-0f4edf3e881efde00` (`rido-sg`): 22 from the owner's IP only, 3000–3001 public; Postgres/Redis not published |
| SSH | `ssh -i ~/.ssh/rido-key.pem ubuntu@65.0.233.253` |
| On server | `/opt/rido`: `docker-compose.yml`, `docker-compose.prod.yml` (removes DB/Redis host ports), `.env` (generated JWT secret + DB password, `S3_BUCKET`, mode 600) |
| Uploads (S3) | Bucket `rido-uploads-786020471552` (ap-south-1): all public access blocked, SSE-S3 default encryption, ACLs off. The instance role `rido-ec2-uploads` may only Put/Get `kyc/*` and List with prefix `kyc/` (no keys on the server). IMDSv2 required, hop limit 2 (so the API container can reach instance credentials) |

**Seed prod** (the image has no TS sources, so seeders run locally through an SSH tunnel; ids `demo_…`, removable with `--clear`):

```bash
PGIP=$(ssh -i ~/.ssh/rido-key.pem ubuntu@65.0.233.253 "docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' rido-postgres-1")
ssh -i ~/.ssh/rido-key.pem -f -N -L 15432:$PGIP:5432 ubuntu@65.0.233.253
DATABASE_URL="postgresql://rido:<POSTGRES_PASSWORD from /opt/rido/.env>@127.0.0.1:15432/rido" npm run seed:demo-people -w @rido/api
```

Seeded 26 Sep 2026: 2,000 demo trips + demo people.

**Capacity (measured 26 Sep 2026, t3.small):** cached fare quotes at 50 concurrent connections: ~890 req/s average
(peak 1,340), p50 43 ms, p99 ~200 ms, no errors; the API process used both vCPUs while Postgres/Redis stayed idle.
Planning figures with headroom: ~300–400 req/s sustained, ~1,500–2,500 concurrent app users, ~300–500 online
drivers (GPS every 5 s over the socket), ~5 bookings/s at peak, ~5,000–10,000 trips/day. Limits, in order: one Node
process; t3 CPU credits (baseline 20 %/vCPU: sustained load either drains credits or bills "unlimited" surplus);
2 GB RAM shared with Postgres/Redis; single server (no failover). Next steps: c7i-flex.large or t3.medium; then
RDS + 2 API instances behind an ALB with the Socket.IO Redis adapter (events are per process today).

HTTP keep-alive is 65 s (`main.ts`); with Node's 5 s default the apps sometimes reused a closed connection and showed
"You're offline". The apps also retry idempotent requests once after a dropped connection (`ApiClient`).

**Redeploy** (images are built locally so the small instance never runs `next build`):

```bash
set -a; . ./.env; set +a
docker build -f apps/api/Dockerfile -t rido-api:local .
docker build -f apps/admin/Dockerfile --build-arg NEXT_PUBLIC_GOOGLE_MAPS_BROWSER_KEY="$GOOGLE_MAPS_BROWSER_KEY" -t rido-admin:local .
docker save rido-api:local rido-admin:local | gzip -1 | ssh -i ~/.ssh/rido-key.pem ubuntu@65.0.233.253 'gunzip | docker load'
ssh -i ~/.ssh/rido-key.pem ubuntu@65.0.233.253 'cd /opt/rido && docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d --no-build'
```

If your IP changes, SSH times out: re-authorize port 22 in `rido-sg` for the new IP. An Elastic IP costs money while it isn't attached to a running instance, so release it if the server is terminated.

---

## 10. Not done yet / next steps

| Item | Notes |
|---|---|
| Apps → API | **Done (26 Sep 2026)**: both apps run on the API by default (see 7b); mock mode via `--dart-define=RIDO_LIVE_API=false`. Needs a real-phone pass (two phones: passenger + approved online driver) |
| Push (FCM) | **Done (26 Sep 2026)**, see 7c. Verify on phones; rotate the service-account key that was pasted in chat (`e73622ac…`) and update `FIREBASE_SERVICE_ACCOUNT_B64` on the server |
| Driver re-search | A driver cancel ends the trip (CANCELLED); re-dispatch instead so the passenger's S-02 "finding another driver" is real |
| Trip `updatedAt` | Add to Trip JSON so apps can order pushed updates reliably (apps guard with a status order today) |
| SOS / tracking link | No SOS service (apps raise a "Safety concern" ticket + dialer) and no public trip-tracking page yet |
| Women-driver preference | App toggle is not sent: booking has no field and dispatch doesn't filter by driver gender |
| Selfie / DOB | Daily selfie (S-13 / D-09) and sign-up photo are simulated; date of birth isn't stored |
| CI | Add GitHub Actions: `npm ci`, `npm run check`, API e2e with service containers, APK build artifacts |
| Hosting | **Staging live (26 Sep 2026)**: see "9b. AWS deployment". Later: HTTPS + domain, RDS/ElastiCache when load needs it |
| Secrets | AWS Secrets Manager / SSM for `JWT_SECRET`, Google keys, DB password |
| Observability | Structured logs → CloudWatch; health checks already exposed |
| Payments | Razorpay Subscriptions (UPI Autopay mandates) |
| SMS | MSG91 / Twilio for OTP |
| Admin panel | **Done (25 Sep 2026)**: `apps/admin`, all modules above. KYC files open via `/files/:name` (S3). Follow-up: no 2FA/IP allow-list for admins yet |
| Google Maps on device | Verify the Google engine on a real phone with keys (never run with a key yet) |
| Google logo padding | **Done**: `RidoMap.mapPadding` (→ `GoogleMap.padding`) on map screens with sheets; the shared camera-fit still ignores it (passenger works around it with `sheetMapInsets`) |
| Two-wheeler routing | **Done**: `travelModeFor(vehicle)` on every leg; backend routes bikes as TWO_WHEELER. Route cache key ignores the mode (minor) |
| Google search in pickers | **Done**: saved-place editor and parcel picker search through the API |
| H3 | See plan below |

---

## H3 plan (owner recommendation #1)

[H3](https://h3geo.org) (Uber's hexagonal grid). **Implemented (25 Sep 2026)**; references: https://www.uber.com/in/en/blog/h3/ and "How Uber finds your driver in seconds".

| Use | How | Replaces |
|---|---|---|
| Driver–passenger matching | **Done (25 Sep 2026):** drivers indexed at res 8; pickup hex then rings outward; ranked by road ETA per hex pair; batched assignment | Redis GEOSEARCH radius (removed) |
| Demand zones and surge | **Done:** bookings counted per res-7 hex per minute as **distinct passengers** (Redis set `h3:riders:<min>:<cell>`, 26 Sep 2026; one person retrying can't create surge; cells in `h3:req:<min>`); every 60 s `DemandService` compares requests (last `demandWindowMin`) with free drivers in the hex → `surgeFor` (1 + sensitivity × (ratio − 1), ≤ maxMultiplier, floor 0.05) → **k-ring smoothing** (own × 0.6 + ring-1 mean × 0.4, avoids price cliffs at hex edges) → `h3:surge:<cell>` (3 min TTL). Fares use max(zone surge / default, live surge). Public `GET /v1/demand` for the driver app's "High demand" areas | Hard-coded demand circles |
| ETA | **Done (multi-resolution 26 Sep 2026):** `HexStatsService` aggregates completed trips (60 days, 3–80 km/h) into `HexStat` at **res 9, 8 and 7** (`res` column; from → to, IST hour, trips, speed = total km / total time, avg minutes); rebuilt daily (Redis lock) or `POST /v1/admin/hex-stats/rebuild`; kept in memory. Lookup backs off: exact hour at res 9 → 8 → 7, then the all-day average at res 9 → 8 → 7, first with ≥ `historicalEtaMinTrips`. `EtaService` order: learned speed from the exact points (in memory, free) → Google Routes → 20 km/h estimate (`geo/eta-model.ts`); road/estimate cached per res-8 cell pair 10 min | 18 km/h constant; res-7 only |

Resolutions used: res 8 (≈0.74 km²) for service areas, zones, the driver index, trip cells and heatmaps; res 7
(≈5 km², parent of 7 res-8 cells) for demand/supply and surge; learned speeds at res 9 (≈0.1 km²), 8 and 7 with
back-off, so busy streets get street-level speeds while quiet areas still get a stable district average.
Compaction: `GET /v1/cities/:id/service-area?compact=true` returns `compactCells` output (mixed resolutions) for
small app payloads. Still optional: `h3_flutter` in the driver app to draw `/v1/demand` hexes (apps use mock data today).

Status (25 Sep 2026): **all parts live** (service areas, zones, dispatch, heatmaps, live surge, learned ETA). New settings:
dynamicSurgeEnabled, surgeSensitivity, demandWindowMin, surgeMinRequests, historicalEtaMinTrips.

Fixed 25 Sep 2026: `/admin/users?role=&blocked=` (added to `ListQueryDto`) and the API image seed crash (`h3.util.ts`
copied into the runtime image).

Gotcha learned: Prisma queries are lazy; `void prisma.x.create(...)` never runs. Always `await` or attach `.catch()`.
