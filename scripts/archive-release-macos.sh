#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/lib/xcodebuild-clean.sh"
PROJECT_PATH="$ROOT_DIR/LimitBar.xcodeproj"
SCHEME="LimitBar"
DESTINATION="${DESTINATION:-generic/platform=macOS}"
ARCHIVE_PATH="${ARCHIVE_PATH:-$ROOT_DIR/build/archive/LimitBar.xcarchive}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/build/DerivedData}"

mkdir -p "$(dirname "$ARCHIVE_PATH")" "$DERIVED_DATA_PATH"

TEAM_ARGS=()
if [[ -n "${DEVELOPMENT_TEAM:-}" ]]; then
  TEAM_ARGS+=("DEVELOPMENT_TEAM=$DEVELOPMENT_TEAM")
fi

COMMAND=(
  run_xcodebuild
  -project "$PROJECT_PATH"
  -scheme "$SCHEME"
  -configuration Release
  -destination "$DESTINATION"
  -derivedDataPath "$DERIVED_DATA_PATH"
  -archivePath "$ARCHIVE_PATH"
  archive
)

if [[ ${#TEAM_ARGS[@]} -gt 0 ]]; then
  COMMAND+=("${TEAM_ARGS[@]}")
fi

"${COMMAND[@]}"
