#!/usr/bin/env bash

set -euo pipefail

PROFILE="${1:-${NOTARYTOOL_PROFILE:-limitbar-notary}}"
IDENTITIES="$(security find-identity -v -p codesigning)"
DEV_ID_IDENTITIES="$(printf '%s\n' "$IDENTITIES" | grep -F '"Developer ID Application:' | grep -Fv 'CERT_REVOKED' || true)"

echo "Release signing preflight"
echo "========================"

if [[ -n "$DEV_ID_IDENTITIES" ]]; then
  echo
  echo "Developer ID Application identities:"
  printf '%s\n' "$DEV_ID_IDENTITIES"
else
  echo
  echo "Developer ID Application identities: missing"
fi

echo
if xcrun notarytool history --keychain-profile "$PROFILE" >/dev/null 2>&1; then
  echo "Notarytool profile '$PROFILE': ready"
  NOTARY_READY=1
else
  echo "Notarytool profile '$PROFILE': missing"
  NOTARY_READY=0
fi

echo
if [[ -z "$DEV_ID_IDENTITIES" ]]; then
  echo "Next step: import a valid Developer ID Application certificate into Keychain Access." >&2
  exit 1
fi

if [[ "$NOTARY_READY" -ne 1 ]]; then
  echo "Next step: run 'xcrun notarytool store-credentials $PROFILE'." >&2
  exit 1
fi

echo "Machine is ready for './scripts/release-developer-id-macos.sh'."
