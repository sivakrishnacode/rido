# Rido (passenger app)

Flutter app for riders: book bike, auto and cab rides, send parcels, track the driver live, share the trip, SOS.
Android id `com.rido.passenger`. Workspace name `@rido/passenger`.

```bash
sh ../../scripts/flutter.sh run                                              # talks to the default API
sh ../../scripts/flutter.sh run --dart-define=RIDO_API_URL=http://10.0.2.2:3000/v1  # your local API (emulator)
sh ../../scripts/flutter.sh run --dart-define=RIDO_LIVE_API=false            # no backend: seed data + simulator
npx turbo run analyze test --filter=@rido/passenger
```

```
lib/
  main.dart, app.dart
  router/         go_router 17 routes (pinned: 18 needs material_ui)
  state/          Riverpod flow controllers (ride, parcel, live trip…)
  common/         shell, helpers
  features/<f>/   one file per screen, named after its design frame (P10ChooseVehicleScreen = docs/design P-10)
  features/design_gallery/  every frame on its own + demo controls
```

Shared code lives in [`packages/rido_ui`](../../packages/rido_ui) (widgets, theme) and
[`packages/rido_data`](../../packages/rido_data) (models, API client, fare engine). See the
[root README](../../README.md) and [CONTRIBUTING.md](../../CONTRIBUTING.md).
