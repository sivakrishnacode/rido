# Tamil Taxi Driver (driver app)

Flutter app for ride and delivery drivers:

- go online and see demand hexes;
- take requests: swipe to accept, read aloud, up to 3 open at once;
- navigate, collect the fare, view earnings;
- identity checks at sign-up;
- a floating bubble (`lib/overlay`, using the vendored
  [`flutter_overlay_window`](../../packages/flutter_overlay_window)) that keeps requests coming while other apps are open.

Android id `com.tamiltaxi.driver`. Workspace name `@tamiltaxi/driver`.

```bash
sh ../../scripts/flutter.sh run                                              # talks to the default API
sh ../../scripts/flutter.sh run --dart-define=TT_API_URL=http://10.0.2.2:3000/v1  # your local API (emulator)
sh ../../scripts/flutter.sh run --dart-define=TT_LIVE_API=false            # no backend: seed data + simulator
npx turbo run analyze test --filter=@tamiltaxi/driver
```

Test accounts on a local backend: `npm run seed:test-drivers -w @tamiltaxi/api` (11 approved drivers, every vehicle type).

Layout is the same as the passenger app (`router/`, `state/`, `features/<feature>/` named after design frames,
`features/design_gallery/`), plus `overlay/` for the background bubble. Background behaviour and request handling:
[using.tech.md §7c9 and §7d](../../docs/tech-docs/using.tech.md#7d-driver-app-in-the-background-appsdriverliboverlay).
