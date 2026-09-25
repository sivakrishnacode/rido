#!/usr/bin/env sh
# Runs the Dart SDK bundled with Flutter ($FLUTTER, PATH, or ~/development/flutter).
if [ -n "$FLUTTER" ]; then exec "$(dirname "$FLUTTER")/dart" "$@"; fi
if command -v flutter >/dev/null 2>&1; then exec "$(dirname "$(command -v flutter)")/dart" "$@"; fi
if [ -x "$HOME/development/flutter/bin/dart" ]; then exec "$HOME/development/flutter/bin/dart" "$@"; fi
echo "dart not found: add Flutter to PATH or set FLUTTER=/path/to/flutter/bin/flutter" >&2
exit 1
