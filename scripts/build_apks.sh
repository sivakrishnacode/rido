#!/usr/bin/env bash
# Builds release APKs into ./dist (same result as `npm run build:apk`, no Node needed).
#
#   ./scripts/build_apks.sh                 # both apps, one universal APK each (~60 MB)
#   ./scripts/build_apks.sh passenger       # one app (passenger | driver)
#   ./scripts/build_apks.sh --split         # per-CPU APKs (~20 MB each); install the arm64-v8a one on modern phones
#
# Google keys come from the git-ignored .dart-defines.json (GOOGLE_MAPS_API_KEY for the app, MAPS_API_KEY for the
# map SDK, read by Gradle). Without it the apps build fine and use the CARTO / OSRM fallback.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FL="$ROOT/scripts/flutter.sh"
SPLIT=false
APPS=()
for arg in "$@"; do
  case "$arg" in
    --split) SPLIT=true ;;
    passenger|driver) APPS+=("$arg") ;;
    *) echo "Unknown argument: $arg (use passenger, driver or --split)" >&2; exit 1 ;;
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
  if $SPLIT; then
    sh "$FL" build apk --release --split-per-abi
    for f in build/app/outputs/flutter-apk/app-*-release.apk; do
      abi="$(basename "$f" | sed -E 's/app-(.*)-release.apk/\1/')"
      cp "$f" "$ROOT/dist/rido-$app-$abi.apk"
    done
    out="$ROOT/dist/rido-$app-arm64-v8a.apk"
  else
    sh "$FL" build apk --release
    out="$ROOT/dist/rido-$app.apk"
    cp build/app/outputs/flutter-apk/app-release.apk "$out"
  fi
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
