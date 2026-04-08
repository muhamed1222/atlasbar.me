#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXPORT_PATH="${EXPORT_PATH:-$ROOT_DIR/build/export/developer-id}"
APP_PATH="${APP_PATH:-$(find "$EXPORT_PATH" -maxdepth 1 -name '*.app' -print | head -n 1)}"
ZIP_PATH="${ZIP_PATH:-$ROOT_DIR/build/export/LimitBar-macOS.zip}"
NOTARYTOOL_PROFILE="${NOTARYTOOL_PROFILE:-}"

if [[ -z "$APP_PATH" || ! -d "$APP_PATH" ]]; then
  echo "Exported .app not found. Run ./scripts/export-developer-id-macos.sh first." >&2
  exit 1
fi

if [[ -z "$NOTARYTOOL_PROFILE" ]]; then
  echo "Set NOTARYTOOL_PROFILE to a keychain profile created with 'xcrun notarytool store-credentials'." >&2
  exit 1
fi

mkdir -p "$(dirname "$ZIP_PATH")"
rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

xcrun notarytool submit "$ZIP_PATH" --keychain-profile "$NOTARYTOOL_PROFILE" --wait
xcrun stapler staple "$APP_PATH"
spctl --assess --type execute --verbose=4 "$APP_PATH"

echo "Notarized and stapled $APP_PATH"
