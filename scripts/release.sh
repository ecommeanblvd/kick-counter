#!/usr/bin/env bash
# Archives the app and uploads it to App Store Connect (TestFlight).
# Runs on GitHub Actions; uses cloud-managed signing via an App Store Connect API key.
set -euo pipefail
: "${ASC_KEY_ID:?}" "${ASC_ISSUER_ID:?}" "${DEVELOPMENT_TEAM:?}" "${BUILD_NUMBER:?}"
cd "$(dirname "$0")/.."

KEY_PATH="$HOME/private_keys/AuthKey_${ASC_KEY_ID}.p8"
[[ -f "$KEY_PATH" ]] || { echo "Missing API key at $KEY_PATH" >&2; exit 1; }
AUTH=(-allowProvisioningUpdates
      -authenticationKeyPath "$KEY_PATH"
      -authenticationKeyID "$ASC_KEY_ID"
      -authenticationKeyIssuerID "$ASC_ISSUER_ID")

xcodegen generate --quiet
rm -rf build && mkdir -p build

# TestFlight builds show pregnancy content still awaiting the obstetrician's
# review (CONTENT_PREVIEW=1, set by testflight.yml). App Store builds must not set it.
EXTRA_SETTINGS=()
if [[ "${CONTENT_PREVIEW:-0}" == "1" ]]; then
  EXTRA_SETTINGS+=('SWIFT_ACTIVE_COMPILATION_CONDITIONS=$(inherited) CONTENT_PREVIEW' 'LUNA_CONTENT_PREVIEW=YES')
  echo "==> CONTENT_PREVIEW enabled"
fi

xcodebuild -project KickCounter.xcodeproj -scheme KickCounter \
  -configuration Release -destination "generic/platform=iOS" \
  -archivePath build/KickCounter.xcarchive \
  DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" CODE_SIGN_STYLE=Automatic \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  ${EXTRA_SETTINGS[@]+"${EXTRA_SETTINGS[@]}"} \
  "${AUTH[@]}" archive

cat > build/ExportOptions.plist <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key><string>app-store-connect</string>
    <key>destination</key><string>upload</string>
    <key>teamID</key><string>${DEVELOPMENT_TEAM}</string>
    <key>signingStyle</key><string>automatic</string>
    <key>manageAppVersionAndBuildNumber</key><false/>
</dict>
</plist>
EOF

xcodebuild -exportArchive \
  -archivePath build/KickCounter.xcarchive \
  -exportOptionsPlist build/ExportOptions.plist \
  -exportPath build/export \
  "${AUTH[@]}"
echo "==> Uploaded build $BUILD_NUMBER to App Store Connect"
