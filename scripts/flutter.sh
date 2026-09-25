#!/usr/bin/env sh
# Runs Flutter from $FLUTTER, from PATH, or from ~/development/flutter (in that order).
if [ -n "$FLUTTER" ]; then exec "$FLUTTER" "$@"; fi
if command -v flutter >/dev/null 2>&1; then exec flutter "$@"; fi
if [ -x "$HOME/development/flutter/bin/flutter" ]; then exec "$HOME/development/flutter/bin/flutter" "$@"; fi
echo "flutter not found: add it to PATH or set FLUTTER=/path/to/flutter/bin/flutter" >&2
exit 1
