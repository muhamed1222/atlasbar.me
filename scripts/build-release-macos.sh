#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/lib/xcodebuild-clean.sh"
PROJECT_PATH="$ROOT_DIR/LimitBar.xcodeproj"
SCHEME="LimitBar"
DESTINATION="${DESTINATION:-platform=macOS,arch=arm64}"

run_xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination "$DESTINATION" \
  build
