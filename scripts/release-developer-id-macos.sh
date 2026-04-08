#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

"$ROOT_DIR/scripts/archive-release-macos.sh"
"$ROOT_DIR/scripts/export-developer-id-macos.sh"
"$ROOT_DIR/scripts/notarize-macos.sh"
