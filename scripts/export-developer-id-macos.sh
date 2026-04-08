#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/lib/xcodebuild-clean.sh"
ARCHIVE_PATH="${ARCHIVE_PATH:-$ROOT_DIR/build/archive/LimitBar.xcarchive}"
EXPORT_PATH="${EXPORT_PATH:-$ROOT_DIR/build/export/developer-id}"
SIGNING_CERTIFICATE="${SIGNING_CERTIFICATE:-Developer ID Application}"
IDENTITIES="$(security find-identity -v -p codesigning)"

if [[ ! -d "$ARCHIVE_PATH" ]]; then
  echo "Archive not found at $ARCHIVE_PATH. Run ./scripts/archive-release-macos.sh first." >&2
  exit 1
fi

if ! printf '%s\n' "$IDENTITIES" | grep -F "\"$SIGNING_CERTIFICATE\"" | grep -Fv "CERT_REVOKED" >/dev/null; then
  echo "No valid codesigning identity matching '$SIGNING_CERTIFICATE' was found." >&2
  echo "Install a Developer ID Application certificate before exporting a distributable build." >&2
  exit 1
fi

mkdir -p "$EXPORT_PATH"
EXPORT_OPTIONS_PLIST="$(mktemp "${TMPDIR:-/tmp}/limitbar-export-options.XXXXXX.plist")"
trap 'rm -f "$EXPORT_OPTIONS_PLIST"' EXIT

cat >"$EXPORT_OPTIONS_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>destination</key>
  <string>export</string>
  <key>method</key>
  <string>developer-id</string>
  <key>signingStyle</key>
  <string>automatic</string>
  <key>signingCertificate</key>
  <string>${SIGNING_CERTIFICATE}</string>
</dict>
</plist>
EOF

if [[ -n "${DEVELOPMENT_TEAM:-}" ]]; then
  /usr/libexec/PlistBuddy -c "Add :teamID string $DEVELOPMENT_TEAM" "$EXPORT_OPTIONS_PLIST"
fi

run_xcodebuild \
  -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS_PLIST"

APP_PATH="$(find "$EXPORT_PATH" -maxdepth 1 -name '*.app' -print | head -n 1)"
if [[ -z "$APP_PATH" ]]; then
  echo "Export succeeded but no .app was found in $EXPORT_PATH." >&2
  exit 1
fi

codesign --verify --deep --strict "$APP_PATH"
spctl --assess --type execute --verbose=4 "$APP_PATH"
echo "Exported Developer ID app to $APP_PATH"
