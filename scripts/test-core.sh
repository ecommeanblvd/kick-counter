#!/usr/bin/env bash
# Local gate that works without Xcode: KickCore unit tests.
# Extra arguments are passed to `swift test` (e.g. --filter SessionEngineTests).
set -euo pipefail
cd "$(dirname "$0")/../Packages/KickCore"

DEV_DIR="$(xcode-select -p)"
if [[ "$DEV_DIR" == *CommandLineTools* ]]; then
  # Command Line Tools ship Swift Testing, but SwiftPM doesn't find it by default.
  FRAMEWORKS="$DEV_DIR/Library/Developer/Frameworks"
  LIBS="$DEV_DIR/Library/Developer/usr/lib"
  swift test \
    -Xswiftc -F -Xswiftc "$FRAMEWORKS" \
    -Xlinker -F -Xlinker "$FRAMEWORKS" \
    -Xlinker -rpath -Xlinker "$FRAMEWORKS" \
    -Xlinker -rpath -Xlinker "$LIBS" \
    "$@"
else
  swift test "$@"
fi
