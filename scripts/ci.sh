#!/usr/bin/env bash
# Full quality gate. Runs on GitHub Actions (requires Xcode + XcodeGen).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "==> KickCore unit tests"
scripts/test-core.sh

if [[ -d Packages/KickData ]]; then
  echo "==> KickData unit tests"
  (cd Packages/KickData && swift test)
fi

echo "==> Generating Xcode project"
xcodegen generate --quiet

DEVICE_ID="$(xcrun simctl list devices available | grep -m1 -E '^[[:space:]]+iPhone' | grep -oE '[0-9A-F]{8}-([0-9A-F]{4}-){3}[0-9A-F]{12}')"
[[ -n "$DEVICE_ID" ]] || { echo "No available iPhone simulator" >&2; exit 1; }

XCODE_ACTION="build"
rm -rf build && mkdir -p build/screenshots
echo "==> xcodebuild $XCODE_ACTION on simulator $DEVICE_ID"
STATUS=0
xcodebuild -project KickCounter.xcodeproj -scheme KickCounter \
  -destination "id=$DEVICE_ID" \
  -resultBundlePath build/KickCounter.xcresult \
  CODE_SIGNING_ALLOWED=NO -quiet "$XCODE_ACTION" || STATUS=$?

if [[ "$XCODE_ACTION" == "test" ]]; then
  echo "==> Exporting screenshots"
  xcrun xcresulttool export attachments --path build/KickCounter.xcresult --output-path build/screenshots || true
  python3 - <<'PY'
import json, os
d = "build/screenshots"
manifest = os.path.join(d, "manifest.json")
if os.path.exists(manifest):
    for test in json.load(open(manifest)):
        for a in test.get("attachments", []):
            src = os.path.join(d, a["exportedFileName"])
            name = a.get("suggestedHumanReadableName") or a["exportedFileName"]
            if os.path.exists(src):
                os.rename(src, os.path.join(d, name))
PY
fi

[[ $STATUS -eq 0 ]] && echo "==> All checks passed"
exit $STATUS
