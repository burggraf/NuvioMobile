#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
VERSION="$(sed -nE 's/^[[:space:]]*MARKETING_VERSION[[:space:]]*=[[:space:]]*([^[:space:]#]+).*$/\1/p' "$ROOT_DIR/iosApp/Configuration/Version.xcconfig" | head -n 1)"
BUILD_NUMBER="${IOS_BUILD_NUMBER:-$(date +%s)}"
TEAM_ID="${APPLE_TEAM_ID:-}"
RELEASE_DIR="${RELEASE_DIR:-$ROOT_DIR/build/testflight}"
UPLOAD=true

usage() {
  cat <<'EOF'
Usage: scripts/release/testflight.sh [--no-upload] [--build-number NUMBER]

Builds and signs an iOS archive, exports an App Store Connect IPA, and uploads
it to TestFlight by default.

Required for archive:
  APPLE_TEAM_ID                  Apple Developer team ID
  NUVIO_SUPABASE_URL             official backend URL
  NUVIO_SUPABASE_ANON_KEY        public/publishable key (local.properties also works)

Required for upload:
  APPLE_ID                       App Store Connect Apple ID email
  APPLE_APP_SPECIFIC_PASSWORD    Apple app-specific password
                                 (APPLE_PASSWORD also supported)

Optional:
  IOS_BUILD_NUMBER               defaults to the current Unix timestamp
  RELEASE_DIR                    defaults to build/testflight
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-upload) UPLOAD=false; shift ;;
    --build-number)
      [[ $# -ge 2 ]] || { echo "Missing value for --build-number" >&2; exit 2; }
      BUILD_NUMBER="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

[[ "$BUILD_NUMBER" =~ ^[0-9]+$ ]] || { echo "Build number must be numeric: $BUILD_NUMBER" >&2; exit 2; }
[[ -n "$VERSION" ]] || { echo "MARKETING_VERSION is missing from Version.xcconfig" >&2; exit 1; }
[[ -n "$TEAM_ID" ]] || { echo "APPLE_TEAM_ID is required" >&2; exit 1; }
command -v xcodebuild >/dev/null || { echo "Missing command: xcodebuild (install Xcode)" >&2; exit 1; }
command -v xcrun >/dev/null || { echo "Missing command: xcrun (install Xcode)" >&2; exit 1; }

if [[ "$UPLOAD" == true ]]; then
  [[ -n "${APPLE_ID:-}" ]] || { echo "APPLE_ID is required for upload" >&2; exit 1; }
  UPLOAD_PASSWORD="${APPLE_APP_SPECIFIC_PASSWORD:-${APPLE_PASSWORD:-}}"
  [[ -n "$UPLOAD_PASSWORD" ]] || { echo "APPLE_APP_SPECIFIC_PASSWORD or APPLE_PASSWORD is required" >&2; exit 1; }
fi

ARCHIVE_DIR="$ROOT_DIR/build/testflight"
ARCHIVE="$ARCHIVE_DIR/Nuvio-${VERSION}-${BUILD_NUMBER}.xcarchive"
EXPORT_DIR="$ARCHIVE_DIR/export-${BUILD_NUMBER}"
EXPORT_OPTIONS="$ARCHIVE_DIR/export-options-${BUILD_NUMBER}.plist"
mkdir -p "$ARCHIVE_DIR" "$RELEASE_DIR"

cat > "$EXPORT_OPTIONS" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>method</key><string>app-store-connect</string>
<key>signingStyle</key><string>automatic</string>
<key>teamID</key><string>$TEAM_ID</string>
</dict></plist>
EOF

cd "$ROOT_DIR"
echo "==> Preparing iOS dependencies"
./scripts/prepare-ios-dependencies.sh

echo "==> Archiving Nuvio iOS $VERSION ($BUILD_NUMBER) for TestFlight"
NUVIO_IOS_DISTRIBUTION=full NUVIO_REQUIRE_BACKEND_CONFIG=1 xcodebuild \
  -project iosApp/iosApp.xcodeproj \
  -scheme iosApp \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE" \
  -allowProvisioningUpdates \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  archive

[[ -d "$ARCHIVE/Products/Applications/Nuvio.app" ]] || { echo "No Nuvio.app found in $ARCHIVE" >&2; exit 1; }
APP_BINARY="$ARCHIVE/Products/Applications/Nuvio.app/Nuvio"
PRIVATE_GCM_SYMBOLS="$(xcrun nm -u "$APP_BINARY" | awk '$NF ~ /^_CCCryptorGCM(Decrypt|Encrypt|Final)$/ { print $NF }')"
if [[ -n "$PRIVATE_GCM_SYMBOLS" ]]; then
  echo "Private CommonCrypto AES-GCM APIs are not App Store-safe:" >&2
  printf '%s\n' "$PRIVATE_GCM_SYMBOLS" >&2
  exit 1
fi

xcodebuild -quiet -allowProvisioningUpdates -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist "$EXPORT_OPTIONS"

IPA="$(find "$EXPORT_DIR" -type f -name '*.ipa' -print -quit)"
[[ -n "$IPA" && -f "$IPA" ]] || { echo "No IPA produced under $EXPORT_DIR" >&2; exit 1; }
DEST="$RELEASE_DIR/nuvio-ios-v${VERSION}-b${BUILD_NUMBER}.ipa"
cp -f "$IPA" "$DEST"
echo "==> IPA: $DEST"

if [[ "$UPLOAD" == true ]]; then
  echo "==> Uploading to TestFlight"
  APPLE_UPLOAD_PASSWORD="$UPLOAD_PASSWORD" xcrun altool --upload-app -f "$DEST" \
    -u "$APPLE_ID" \
    -p '@env:APPLE_UPLOAD_PASSWORD'
  echo "==> Upload accepted; processing in App Store Connect may take a few minutes"
else
  echo "==> Upload skipped (--no-upload)"
fi
