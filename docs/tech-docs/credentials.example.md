# Rido credentials template

Never commit this file or paste its contents into tickets, chats or docs. Rotate any key that leaks.
Git-ignored by `/.gitignore` (`docs/tech-docs/credentials*`). Keep a copy in a password manager.

Last updated: 25 Sep 2026

## Google Cloud (project `rido-prod`)

| Name | Key | Used in | Restrictions |
|---|---|---|---|
| rido-android-maps | `<key>` | `apps/passenger/android/local.properties`, `apps/driver/android/local.properties` (`MAPS_API_KEY`) | None for now (planned: Android apps + SHA-1, Maps SDK for Android) |
| rido-server | `<key>` | `/.env`, `apps/api/.env` (`GOOGLE_MAPS_API_KEY`) | None for now (planned: IP address, Places/Geocoding/Routes) |
| rido-app-services | `<key>` | `/.dart-defines.json` (`GOOGLE_MAPS_API_KEY`) | None for now (planned: Places/Geocoding/Routes only) |

Auto-created "Maps Platform API Key": delete it (unused).

## Android signing

| Keystore | Alias | Passwords | SHA-1 |
|---|---|---|---|
| `~/.android/debug.keystore` (debug) | androiddebugkey | android / android | `<sha1>` |
| Release keystore | not created yet | – | – |

## Backend (Docker Compose, local)

| Item | Value | Where |
|---|---|---|
| Postgres | user `rido`, password `rido`, db `rido`, host port 5432 | `/.env` |
| Redis | no password, host port 6380 | `/.env` |
| JWT_SECRET (dev) | `change-me-to-a-long-random-string-32chars` (Docker), `dev-only-change-me` (local dev) | `/.env`, `apps/api/.env` |
| OTP | dev mode: any 6 digits except `000000` | `OTP_DEV_MODE=true` |

Production: generate a new JWT secret (`openssl rand -hex 32`), set a strong Postgres password and a Redis password.

## Maps (fallback)

| Item | Value | Where |
|---|---|---|
| CARTO basemaps key | `<key>` | default in `packages/rido_ui/lib/src/widgets/rido_map.dart` (override `--dart-define=CARTO_KEY=`) |

The CARTO key is currently in source code as a default; move it to `.dart-defines.json` before the repo becomes public.

## Demo logins

| App | Phone | OTP |
|---|---|---|
| Passenger / Driver | any valid Indian mobile | any 6 digits except `000000` |
| Ride OTP / Delivery OTP (prototype seed) | – | `4829` / `7153` |
