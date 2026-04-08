#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/lib/xcodebuild-clean.sh"
PROJECT_PATH="$ROOT_DIR/LimitBar.xcodeproj"
SCHEME="LimitBar"
DESTINATION="${DESTINATION:-platform=macOS,arch=arm64}"
OUTPUT_DIR="$ROOT_DIR/build/export/local-download"
ZIP_NAME="LimitBar-macOS.zip"

BUILD_SETTINGS="$(
  run_xcodebuild \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -configuration Release \
    -destination "$DESTINATION" \
    -showBuildSettings
)"

TARGET_BUILD_DIR="$(printf '%s\n' "$BUILD_SETTINGS" | awk -F' = ' '/ TARGET_BUILD_DIR = / { print $2; exit }')"
FULL_PRODUCT_NAME="$(printf '%s\n' "$BUILD_SETTINGS" | awk -F' = ' '/ FULL_PRODUCT_NAME = / { print $2; exit }')"

if [[ -z "$TARGET_BUILD_DIR" || -z "$FULL_PRODUCT_NAME" ]]; then
  echo "Unable to resolve release build output path." >&2
  exit 1
fi

run_xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination "$DESTINATION" \
  build >/dev/null

APP_SOURCE="$TARGET_BUILD_DIR/$FULL_PRODUCT_NAME"
ZIP_PATH="$OUTPUT_DIR/$ZIP_NAME"

if [[ ! -d "$APP_SOURCE" ]]; then
  echo "Release app not found in DerivedData." >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR"
rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_SOURCE" "$ZIP_PATH"

echo "Packaged $ZIP_PATH"
