# rido_data

Data layer shared by both Flutter apps (`@rido/data`, not published to pub.dev).

| Folder / file | What |
|---|---|
| `models/` | Trip, driver, vehicle, place… |
| `fare_engine.dart` | `max(minFare, (base + perKm·km + perMin·min) × multiplier)`, the same engine as the API. Both run the shared cases in `test/fixtures/fare_cases.json`, so change them together |
| `api/` | `ApiClient` (REST `/v1`), `RealtimeClient` (Socket.IO `/rt`), `kApiBaseUrl` / `kUseLiveApi` dart-defines |
| `repositories/` | Interfaces the screens use (`api/api_repositories.dart` implements them on the API) |
| `mock/` | In-memory implementations on `seed.dart`, for mock mode and widget tests |
| `simulation/` | Trip simulator and `RoadRouter` (Google → OSRM → curved line) for mock mode |
| `maps/` | Google Places / Routes helpers, polyline codec |
| `providers.dart` | Riverpod providers: live API by default, mock with `--dart-define=RIDO_LIVE_API=false` |

```bash
npx turbo run analyze test --filter=@rido/data
```
