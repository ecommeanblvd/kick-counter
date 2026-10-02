#!/usr/bin/env bash
# Fails unless the built app and its widget extension carry the expected
# version numbers (they must follow MARKETING_VERSION / CURRENT_PROJECT_VERSION).
# Usage: scripts/check-bundle-versions.sh <path/to/KickCounter.app> <expected CFBundleVersion> <expected CFBundleShortVersionString>
set -euo pipefail
APP="$1"
EXPECTED_BUILD="$2"
EXPECTED_VERSION="$3"
PLIST_BUDDY=/usr/libexec/PlistBuddy
STATUS=0
for PLIST in "$APP/Info.plist" "$APP/PlugIns/KickCounterWidgets.appex/Info.plist"; do
  if [[ ! -f "$PLIST" ]]; then
    echo "Missing $PLIST" >&2
    STATUS=1
    continue
  fi
  BUILD="$("$PLIST_BUDDY" -c 'Print :CFBundleVersion' "$PLIST" 2>/dev/null || echo '<missing>')"
  VERSION="$("$PLIST_BUDDY" -c 'Print :CFBundleShortVersionString' "$PLIST" 2>/dev/null || echo '<missing>')"
  if [[ "$BUILD" != "$EXPECTED_BUILD" || "$VERSION" != "$EXPECTED_VERSION" ]]; then
    echo "Version mismatch in $PLIST: CFBundleVersion=$BUILD (expected $EXPECTED_BUILD), CFBundleShortVersionString=$VERSION (expected $EXPECTED_VERSION)" >&2
    STATUS=1
  else
    echo "OK $PLIST: $VERSION ($BUILD)"
  fi
done
exit $STATUS
