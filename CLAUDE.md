# CLAUDE.md — Rido monorepo

Rido is a free ride-hailing and parcel delivery platform for Coimbatore: 0% commission and no subscription for
drivers. The owner pays the running costs; drivers and riders can contribute by UPI (Account › Contribute). Paid
driver plans still exist in the code but are switched off (`driverPlansEnabled`).

This file holds the working rules plus a quick map of the repo. **The full technical reference is
[docs/tech-docs/using.tech.md](docs/tech-docs/using.tech.md)** (stack versions, env vars, endpoints, H3, FCM, AWS).
The owner's recommendations live at the top of that doc.

---

## 1. Working rules (always follow)

### 1.1 Commit every change

Commit **every** completed unit of work: a feature, bug fix, refactor, docs change, config change or dependency bump.
Don't leave finished work uncommitted at the end of a task.

- **One logical change per commit.** Split unrelated changes into separate commits.
- **Commit only once it works.** Run the relevant checks first (see 1.3). If a check fails, fix it or tell the user.
  Don't commit broken code without saying so.
- **Stage files explicitly** (`git add <paths>`), not `git add -A`, so stray files don't get in.
- **Never commit secrets:** `.env`, `.dart-defines.json`, `docs/tech-docs/credentials.local.md`,
  `google-services.json`, Firebase service-account JSON, keystores. They are git-ignored; keep it that way.
- Work on `main` unless the user asks for a branch. **Don't push** unless asked.
- Never use `--no-verify`, `--amend` on pushed commits, or force-push without explicit approval.

**Message format** ([Conventional Commits](https://www.conventionalcommits.org)):

```
<type>(<scope>): <short imperative summary, ≤ 72 chars>

<optional body: what changed and why; list user-visible effects or gotchas>

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
```

| type | use for | | scope | area |
|---|---|---|---|---|
| `feat` | new feature | | `api` | `apps/api` |
| `fix` | bug fix | | `admin` | `apps/admin` |
| `refactor` | no behaviour change | | `passenger` | `apps/passenger` |
| `perf` | performance | | `driver` | `apps/driver` |
| `test` | tests only | | `ui` | `packages/rido_ui` |
| `docs` | docs / CLAUDE.md | | `data` | `packages/rido_data` |
| `chore` | deps, config, tooling | | `infra` | docker, scripts, AWS |
| `revert` | reverting a commit | | `repo` | root / cross-cutting |

Examples: `feat(driver): show H3 demand hexes on home map`, `fix(api): await Prisma write in trip cancel`.

### 1.2 Keep docs current, in the same commit

- **[docs/tech-docs/using.tech.md](docs/tech-docs/using.tech.md)** is the source of truth. Update it whenever the
  stack, services, env vars, commands, endpoints or infra change. Bump its "Last updated" date too, and mark items in
  "10. Not done yet" as **Done (date)** when they ship.
- **This file:** update it when a working rule, a key command or the repo layout changes. Keep it short: details go in
  `using.tech.md`.
- `README.md` is the user-facing intro. Update it for changes that affect setup or how to run things.

### 1.3 Checks before committing

| Changed | Run |
|---|---|
| Flutter (`apps/passenger`, `apps/driver`, `packages/*`) | `npm run analyze` and `npm test` (or `npx turbo run analyze test --filter=@rido/driver`) |
| API | `npm run analyze -w @rido/api && npm test -w @rido/api`; flows/DB: `npm run test:e2e -w @rido/api` |
| Admin | `npm run analyze -w @rido/admin && npm test -w @rido/admin` |
| Everything | `npm run check`. It must pass with **zero analyzer issues** before merging |

### 1.4 Preferences

- **Keep costs low:** free tiers and the smallest infra that works (currently one t3.small EC2 running everything).
- **Admin is on a new Next.js (16):** read [apps/admin/AGENTS.md](apps/admin/AGENTS.md) and the docs in
  `node_modules/next/dist/docs/` before writing admin code.
- **Prisma queries are lazy:** `void prisma.x.create(...)` never runs. Always `await` or attach `.catch()`.

---

## 2. Repo map

```
apps/
  api/          @rido/api        NestJS 12 (ESM) + Prisma 7 (Postgres 17) + Redis 7 + Socket.IO (/rt)
                                 src/core (auth, config, prisma, redis, storage), src/modules/* (one per domain)
  admin/        @rido/admin      Next.js 16 App Router + shadcn/ui + Tailwind v4, port 3001, server-side API calls only
  passenger/    @rido/passenger  Flutter app "Rido"         (com.rido.passenger)
  driver/       @rido/driver     Flutter app "Rido Driver"  (com.rido.driver); lib/overlay = background bubble
packages/
  rido_ui/      @rido/ui         theme, widgets (RidoMap, RidoButton…), illustrations, fonts
  rido_data/    @rido/data       models, seed, fare engine, repositories (mock + api), simulator
  flutter_overlay_window/        vendored plugin for the driver floating bubble
docs/tech-docs/using.tech.md     technical reference (source of truth)
docs/design/                     exported design frames + index
scripts/                         flutter.sh / dart.sh (SDK lookup), build_apks.sh
docker-compose.yml               postgres + redis + api + admin (+ `tools` profile: Adminer, Redis Insight)
```

Flutter app layout: `lib/router` (go_router 17, **pinned**: 18 needs `material_ui`), `lib/state` (Riverpod 3 flow
controllers), `lib/features/<feature>/` (one file per screen, named after its frame ID, e.g. `P10ChooseVehicleScreen`),
`lib/features/design_gallery/` (frame registry + demo controls).

API modules: admin, app-config, auth, drivers, fares, geo (H3), health, maps, notifications (FCM), places, realtime, settings,
subscriptions, support, trips, users.

---

## 3. Common commands

```bash
npm install && npm run get            # deps + flutter pub get + prisma generate
npm run check                         # analyze + test everything (Turborepo, cached)
npm run passenger | npm run driver    # flutter run
./scripts/build_apks.sh [passenger|driver] [--split]   # release APKs → dist/

docker compose up -d                  # full backend stack: API :3000, admin :3001
docker compose up -d postgres redis   # DBs only, then:
npm run start:dev -w @rido/api
npm run dev -w @rido/admin

npm run prisma:migrate -w @rido/api   # new migration (dev)
npm run prisma:seed -w @rido/api      # idempotent seed
npm run seed:demo-trips -w @rido/api  # ~2,000 demo trips (then seed:demo-people)
```

Flutter SDK comes from `$FLUTTER`, `PATH` or `~/development/flutter`. `scripts/flutter.sh` passes
`/.dart-defines.json` (map keys) to every run/build.

---

## 4. Key facts

- **Apps use the live API by default.** Mock mode: `--dart-define=RIDO_LIVE_API=false`.
- **Dev login:** any 6-digit OTP except `000000` (`OTP_DEV_MODE=true`). Admin phone: `9000000001`. Ride OTP `4829`,
  delivery OTP `7153`.
- **Fare engine** (same in the apps and the API): `max(minFare, base + perKm·km + perMin·min) × multiplier (≤ 1.5)`,
  each line rounded down. Demo quotes: ₹38 / ₹72 / ₹145.
- **H3:** res 8 for service areas, zones, the driver index and heatmaps; res 7 for demand and surge; res 9/8/7 for
  learned ETA.
- **Android:** Impeller is forced to OpenGL ES (Vulkan lagged on MediaTek/Mali). Release signing uses debug keys for now.
- **Local Redis runs on port 6380** on this machine (set in `.env`).
- **Staging:** single EC2 at `65.0.233.253` (API `:3000/v1`, admin `:3001`). Images are built locally and loaded over
  SSH. For redeploy steps see `using.tech.md` §9b.

---

## 5. Changelog of this file

| Date | Change |
|---|---|
| 26 Sep 2026 | Created: working rules (commit every change, docs, checks), repo map, commands, key facts |
| 26 Sep 2026 | Free app: intro updated (no subscription, contributions), `app-config` module added to the map |
