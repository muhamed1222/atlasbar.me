#!/usr/bin/env bash

set -euo pipefail

APP_NAME="LimitBar.app"

if [[ -d "/Applications/$APP_NAME" ]]; then
  TARGET="/Applications/$APP_NAME"
elif [[ -d "$HOME/Applications/$APP_NAME" ]]; then
  TARGET="$HOME/Applications/$APP_NAME"
else
  echo "No local installation of $APP_NAME was found." >&2
  exit 1
fi

pkill -x "LimitBar" >/dev/null 2>&1 || true
rm -rf "$TARGET"

echo "Removed $TARGET"
