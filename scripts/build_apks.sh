#!/usr/bin/env bash
# Builds one release APK per app into ./dist: dist/tamiltaxi-passenger.apk and dist/tamiltaxi-driver.apk (same result as
# `npm run build:apk`, no Node needed). Each APK runs on every Android phone (arm64 + 32-bit arm; the x86_64
# emulator build is left out to keep it smaller). Older APKs of that app in dist/ are deleted first.
#
#   ./scripts/build_apks.sh                 # both apps
#   ./scripts/build_apks.sh passenger       # one app (passenger | driver)
#
# Google keys come from the git-ignored .dart-defines.json (GOOGLE_MAPS_API_KEY for the app, MAPS_API_KEY for the
# map SDK, read by Gradle). Without it the apps build fine and use the CARTO / OSRM fallback.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FL="$ROOT/scripts/flutter.sh"
APPS=()
for arg in "$@"; do
  case "$arg" in
    passenger|driver) APPS+=("$arg") ;;
    *) echo "Unknown argument: $arg (use passenger or driver)" >&2; exit 1 ;;
  esac
done
[ ${#APPS[@]} -eq 0 ] && APPS=(passenger driver)

if [ ! -f "$ROOT/.dart-defines.json" ]; then
  echo "! No .dart-defines.json: building WITHOUT Google keys (copy .dart-defines.example.json to add them)."
fi

AAPT="$(ls -d "$HOME"/Android/build-tools/*/aapt 2>/dev/null | tail -1 || true)"
mkdir -p "$ROOT/dist"

for app in "${APPS[@]}"; do
  echo "== Building $app"
  cd "$ROOT/apps/$app"
  sh "$FL" pub get >/dev/null
  sh "$FL" build apk --release --target-platform android-arm,android-arm64
  rm -f "$ROOT"/dist/tamiltaxi-"$app"*.apk
  out="$ROOT/dist/tamiltaxi-$app.apk"
  cp build/app/outputs/flutter-apk/app-release.apk "$out"
  # Check the map SDK key made it into the manifest.
  if [ -n "$AAPT" ]; then
    if "$AAPT" dump xmltree "$out" AndroidManifest.xml | grep -A1 "geo.API_KEY" | grep -q 'AIza'; then
      echo "   map key: set"
    else
      echo "   map key: EMPTY (Google map will not load; the app still works on the CARTO fallback)"
    fi
  fi
done

echo
echo "APKs in $ROOT/dist:"
ls -lh "$ROOT"/dist/*.apk | awk '{print "  " $5 "  " $9}'
