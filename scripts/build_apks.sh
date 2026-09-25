#!/usr/bin/env bash
# Builds release APKs for both apps into ./dist (same as `pnpm build:apk`, without Node).
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FL="$ROOT/scripts/flutter.sh"
mkdir -p "$ROOT/dist"
for app in passenger driver; do
  echo "== Building $app"
  (cd "$ROOT/apps/$app" && sh "$FL" pub get && sh "$FL" build apk --release)
  cp "$ROOT/apps/$app/build/app/outputs/flutter-apk/app-release.apk" "$ROOT/dist/rido-$app.apk"
done
echo "Done: $ROOT/dist/rido-passenger.apk and $ROOT/dist/rido-driver.apk"
