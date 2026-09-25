# Rido: clickable prototype

Two Flutter apps for **Rido**, a zero-commission ride-hailing and parcel delivery platform for Coimbatore:

| App | Folder | Android id | What it does |
|---|---|---|---|
| Rido | `apps/passenger` | `com.rido.passenger` | Book bike / auto / cab rides and send parcels |
| Rido Driver | `apps/driver` | `com.rido.driver` | Ride drivers and delivery drivers: go online, accept jobs, collect fares, manage the plan |

This is a **frontend-only prototype**. There is no backend: every screen reads built-in seed data through mock
repositories, and flows move forward on timers where a real backend would push updates ("driver found",
"driver arrived", a new ride request…).

## Run

Requires Node 20+ (npm), Flutter stable (tested with 3.47 / Dart 3.13) and an Android device or emulator. Flutter is
found via `$FLUTTER`, your `PATH`, or `~/development/flutter` (see `scripts/flutter.sh`).

```bash
npm install          # installs Turborepo
npm run get          # flutter pub get in every package
npm run passenger    # run the passenger app (flutter run)
npm run driver       # run the driver app
```

Both apps are portrait-only, light theme only. Map tiles (CARTO light) need internet; offline, the map shows a plain
background and everything else keeps working. Fonts (Poppins, Inter) are bundled, so no font download is needed.

### Demo tips

- Passenger login: any 6-digit OTP works except `000000` (shows "Incorrect OTP").
- Ride OTP `4829` (the driver enters it), delivery OTP `7153`.
- **Account → Design gallery** (both apps) lists every designed frame (open any of them on its own) and has
  **Demo controls** to force states: no drivers, driver cancels, offline, location denied, outside service area,
  empty activity, slow loading, plan status, KYC rejection, account on hold, failed payment, GPS lost, empty earnings,
  work type (rides / deliveries), **fast mode** (all timers ÷ 3) and **reset all seed data**.
  The gallery is controlled by `kShowDesignGallery` in `lib/common/flags.dart`.

## Monorepo (Turborepo + npm workspaces)

```
apps/
  passenger/          Rido passenger app (Flutter)        @rido/passenger
  driver/             Rido Driver app (Flutter)           @rido/driver
packages/
  rido_ui/            theme, widgets, illustrations       @rido/ui
  rido_data/          models, seed data, fare engine,     @rido/data
                      repositories, simulator, road router
docs/
  PITCH.md, PLAN.md, BUSINESS_MODEL.md, UI_PROMPTS.md, FLUTTER_PROMPT.md
  design/             exported design frames (PNG) + index.md
scripts/
  flutter.sh, dart.sh finds the Flutter / Dart SDK
  build_apks.sh       builds both APKs without Node
dist/                 built APKs (git-ignored)
package.json          npm workspaces + root scripts
turbo.json            task pipeline
```

Each Flutter package has a small `package.json` whose scripts call Flutter, so Turborepo can run them in dependency
order (`@rido/data` → `@rido/ui` → apps) and cache the results.

| Command | What it does |
|---|---|
| `npm run get` | `flutter pub get` everywhere |
| `npm run analyze` | `flutter analyze` everywhere |
| `npm test` | `flutter test` everywhere |
| `npm run check` | analyze + test |
| `npm run format` | `dart format` everywhere |
| `npm run build:apk` | release APKs → `dist/rido-passenger.apk`, `dist/rido-driver.apk` |
| `npm run clean` | `flutter clean` everywhere + Turborepo cache |
| `npx turbo run test --filter=@rido/driver` | one package only |

Inside each app (Flutter layout):

```
lib/
  main.dart, app.dart
  router/routes.dart        route path constants
  router/app_router.dart    every route (go_router, StatefulShellRoute with 4 tabs)
  state/                    Riverpod flow controllers
  common/                   shell, AsyncView, flags, location, phase → route helpers
  features/<feature>/       one file per screen, named after its frame ID (P10ChooseVehicleScreen…)
  features/design_gallery/  gallery screen, frame registry, demo controls
```

## Where the data lives

- **Seed data:** `packages/rido_data/lib/src/seed.dart` (places with coordinates, drivers, passenger, vehicles,
  fare rules, history, chat, tickets, plan, earnings, requests). The prototype runs on a fixed calendar day,
  24 Sep 2026 (`RidoClock`), so the free trial and "next debit 24 Oct 2026" always line up.
- **Fare engine:** `packages/rido_data/lib/src/fare_engine.dart`, a pure function:
  `fare = max(minFare, base + perKm × km + perMin × min) × multiplier (cap 1.5)`, every line rounded down to the rupee
  so the breakdown adds up exactly. Distance = haversine × 1.3 (the demo routes use measured distances), duration =
  distance ÷ 18 km/h. Unit tests: `packages/rido_data/test/fare_engine_test.dart`.
- **Timings:** `SimTimings` in `packages/rido_data/lib/src/demo_settings.dart` (one place; fast mode divides by 3).
- **Simulation:** `TripSimulator` moves vehicle markers along a generated curved path; the flow controllers in
  each app's `lib/state/` chain the timed steps.

## Swapping the mock repositories for a real API

Screens never touch seed data directly. They go through the interfaces in
`packages/rido_data/lib/src/repositories/repositories.dart` (`AuthRepository`, `PlacesRepository`, `RideRepository`,
`ParcelRepository`, `DriverRepository`, `SubscriptionRepository`, `SupportRepository`), exposed as Riverpod providers
in `packages/rido_data/lib/src/providers.dart`.

1. Implement the interface, for example `class HttpRideRepository implements RideRepository { … }`.
2. Override the provider at the app root:
   ```dart
   runApp(ProviderScope(
     overrides: [rideRepositoryProvider.overrideWith((ref) => HttpRideRepository(dio))],
     child: const RidoPassengerApp(),
   ));
   ```
3. Replace the timer-driven steps in `lib/state/*` with your push channel (FCM / WebSocket) events: each controller
   method (for example `RideFlowController._assign`) is the place where a server event would land.

No screen needs to change.

## Quality checks

```bash
npm run check        # analyze + test in all four packages (Turborepo, cached)
```

Each app's tests open **every** Design gallery frame and assert it builds without exceptions or overflow at 360 and
430 px widths, and run the main path end to end with fast mode and fake time (passenger books a bike ride
Gandhipuram → Brookefields through to rating; driver goes online → accepts → OTP 4829 → ends the ride → collects
payment).

`test/tool/shot_test.dart` renders any route to a PNG for comparing with `docs/design/`:

```bash
flutter test test/tool/shot_test.dart --dart-define=ROUTE=/ride/choose-vehicle --dart-define=OUT=/tmp/p10.png
```

## Notes

- `go_router` is pinned to 17.x: 18.x moved to the separately published `material_ui` package, while the other
  dependencies still use `package:flutter/material.dart`, and mixing the two breaks theming and page transitions.
- `google_fonts` is a dev dependency of the apps only so the test harness can wait for fonts; the apps use it through `rido_ui`.
