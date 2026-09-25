# Google Maps Platform: getting and using the API keys

How to create the Google Maps keys for Rido in your Google Cloud (GCP) project, restrict them, cap spending, and plug
them into the apps and the backend. Takes about 15 minutes.

Without keys everything still works: the apps fall back to CARTO map tiles, the free OSRM router and seed places, and
the API falls back to seeded places and straight-line distances.

---

## What you will create

| Key | Used by | APIs it may call | Restricted to |
|---|---|---|---|
| **1. `rido-android-maps`** | Both Android apps, to draw the map | Maps SDK for Android | Android apps `com.rido.passenger` and `com.rido.driver` + signing SHA-1 |
| **2. `rido-server`** | Backend (`apps/api`) | Places API (New), Geocoding API, Routes API | Your server's IP address |
| **3. `rido-app-services`** (prototype only) | Apps' direct search / geocode / route calls | Places API (New), Geocoding API, Routes API | API restrictions only (see note) |

**Why key 3 exists:** the apps currently call Places, Geocoding and Routes directly over HTTPS. Those calls can't
prove they come from the Android app, so an Android-restricted key would be rejected. Key 3 is limited to those
three APIs and capped by quotas. Once the apps talk to the backend (planned), they'll use key 2 through the API and
you can delete key 3.

---

## Step 1: Project and billing

1. Open https://console.cloud.google.com/ and pick your project, or create one: **Select a project → New project**
   (name it e.g. `rido-prod`).
2. Link billing: **Billing → Link a billing account**. Google Maps Platform requires billing even inside the free
   monthly usage.
3. **Set a budget alert before anything else:** **Billing → Budgets & alerts → Create budget**.
   - Scope: this project.
   - Amount: e.g. ₹5,000 per month for the pilot.
   - Alerts at 50%, 90% and 100% by email.

A budget alert only emails you; it doesn't stop spending. The quota caps in Step 5 are what limit cost.

## Step 2: Enable the APIs

Go to **APIs & Services → Library**, search for each and click **Enable**:

- **Maps SDK for Android**
- **Places API (New)** (not the legacy "Places API")
- **Geocoding API**
- **Routes API**

## Step 3: Get your app signing fingerprints (SHA-1)

The Android key only works for apps signed with the certificates you list.

**Debug builds (this machine):**

```bash
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android | grep SHA1
```

This machine's debug SHA-1 is:

```
B5:C9:F1:A3:D4:2E:20:F7:24:2A:F7:94:54:CC:26:36:3B:4D:52:99
```

**Release builds:** when you create a release keystore, run the same command against it. If you publish through
Google Play with Play App Signing, also add the **App signing key SHA-1** from **Play Console → your app → Setup →
App integrity**.

## Step 4: Create the keys

Go to **APIs & Services → Credentials → Create credentials → API key**. For each new key, click **Edit API key**:

### Key 1: `rido-android-maps`
- **Name:** `rido-android-maps`
- **Application restrictions:** Android apps → **Add** twice:
  - Package `com.rido.passenger`, SHA-1 `B5:C9:F1:A3:D4:2E:20:F7:24:2A:F7:94:54:CC:26:36:3B:4D:52:99`
  - Package `com.rido.driver`, same SHA-1
  - Later, add the release / Play signing SHA-1 for both packages.
- **API restrictions:** Restrict key → **Maps SDK for Android** only.

### Key 2: `rido-server`
- **Name:** `rido-server`
- **Application restrictions:** IP addresses → your server's public IP (for local testing, add your own public IP
  from https://ifconfig.me, or leave unrestricted temporarily).
- **API restrictions:** **Places API (New)**, **Geocoding API**, **Routes API**.

### Key 3: `rido-app-services` (prototype only)
- **Name:** `rido-app-services`
- **Application restrictions:** None (see "Why key 3 exists" above).
- **API restrictions:** **Places API (New)**, **Geocoding API**, **Routes API**.

Save each key. Copy the values; they start with `AIza…`.

## Step 5: Cap usage (quotas)

For each of Places API (New), Geocoding API and Routes API: **APIs & Services → Enabled APIs → (API) → Quotas &
System Limits**. Edit **requests per day** to a safe pilot cap, e.g.:

| API | Suggested daily cap (pilot, ~100 rides/day) |
|---|---|
| Places API (New): Autocomplete | 3,000 |
| Places API (New): Place Details | 1,000 |
| Geocoding API | 1,000 |
| Routes API: Compute Routes | 1,500 |

When a cap is hit, calls fail and Rido falls back to local data automatically. Raise the caps as traffic grows.

## Step 6: Put the keys into Rido

Never commit keys. `local.properties` and `.env` files are git-ignored.

**Apps: map (key 1).** Add this line to both files:
- `apps/passenger/android/local.properties`
- `apps/driver/android/local.properties`

```properties
MAPS_API_KEY=AIza...key1
```

**Apps: search, geocode and routes (key 3).** Pass it at run or build time:

```bash
cd apps/passenger
flutter run --dart-define=GOOGLE_MAPS_API_KEY=AIza...key3

# or for both release APKs from the repo root:
GOOGLE_MAPS_APP_KEY=AIza...key3 npm run build:apk
```

Both keys are needed for the full Google experience. Key 1 alone gives the Google map with free routing (OSRM) and
seed search. Key 3 alone does nothing, because the Google engine only turns on when the Dart key is set, and the map
then needs key 1 to load tiles.

**Backend (key 2).** In the root `.env` (Docker) and/or `apps/api/.env` (local dev):

```bash
GOOGLE_MAPS_API_KEY=AIza...key2
```

Then restart: `docker compose up -d api`.

## Step 7: Check it works

```bash
# Backend: "source":"google" means the server key works.
curl "http://localhost:3000/v1/places/autocomplete?q=prozone&session=test1"

curl -X POST http://localhost:3000/v1/maps/route -H 'content-type: application/json' \
  -d '{"from":{"lat":11.0183,"lng":76.9725},"to":{"lat":10.9545,"lng":77.0076}}'
```

In the passenger app:
- Home shows the Google map.
- Typing "Prozone" on the search screen lists Google results.
- The route on Choose a ride follows real roads.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Grey map with the Google logo, no tiles | Key 1 missing, wrong SHA-1 or package, or Maps SDK for Android not enabled | Check `local.properties`, the SHA-1 and the package name; run `flutter clean` and rebuild |
| Search shows only the seed places | Key 3 not passed, restricted wrongly, or quota hit | Run with `--dart-define=GOOGLE_MAPS_API_KEY=...`; key 3 must have **no** Android restriction |
| API returns `"source":"local"` | Key 2 missing, IP not allowed, or API not enabled | Check `.env`, the IP restriction and the enabled APIs; see `docker compose logs api` |
| `403 PERMISSION_DENIED` / `REQUEST_DENIED` in logs | API not enabled, or key restricted to other APIs | Enable the API and add it to the key's API restrictions |
| `This API project is not authorized` | Billing not linked | Link billing (Step 1) |

## Cost notes

- The Maps SDK for Android is free.
- Search uses **session tokens**: all keystrokes of one search plus the one Place Details call bill as one session.
  Details asks only for Essentials fields (`id, formattedAddress, location`).
- Routes use the traffic-unaware (Essentials) option and are computed **once per trip leg**. Live tracking uses the
  driver's GPS over Socket.IO, so there are no Google calls during a trip.
- Results are cached: in Redis on the backend (geocodes 30 days, routes 6 hours, autocomplete 1 day) and in memory
  in the apps.
- At about 1,000 rides/day, ask Google for **Mobility Services** (per-trip pricing), or self-host OSRM/Valhalla
  routing to cut Routes cost to zero.
