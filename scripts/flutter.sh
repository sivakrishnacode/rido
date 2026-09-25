#!/usr/bin/env sh
# Runs Flutter from $FLUTTER, from PATH, or from ~/development/flutter (in that order).
# For `run` and `build`, adds --dart-define-from-file=<repo>/.dart-defines.json when that (git-ignored) file exists.
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [ -n "$FLUTTER" ]; then FL="$FLUTTER"
elif command -v flutter >/dev/null 2>&1; then FL="flutter"
elif [ -x "$HOME/development/flutter/bin/flutter" ]; then FL="$HOME/development/flutter/bin/flutter"
else echo "flutter not found: add it to PATH or set FLUTTER=/path/to/flutter/bin/flutter" >&2; exit 1
fi
if { [ "$1" = "run" ] || [ "$1" = "build" ]; } && [ -f "$ROOT/.dart-defines.json" ]; then
  exec "$FL" "$@" --dart-define-from-file="$ROOT/.dart-defines.json"
fi
exec "$FL" "$@"
