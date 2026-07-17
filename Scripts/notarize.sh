#!/bin/sh
set -eu

dmg_path=${1:-}
test -f "$dmg_path" || { echo "Usage: $0 <path-to.dmg>" >&2; exit 1; }
: "${APPLE_API_KEY_P8:?Set APPLE_API_KEY_P8 to the private-key file path.}"
: "${APPLE_API_KEY_ID:?Set APPLE_API_KEY_ID.}"
: "${APPLE_API_ISSUER_ID:?Set APPLE_API_ISSUER_ID.}"

xcrun notarytool submit "$dmg_path" \
    --key "$APPLE_API_KEY_P8" \
    --key-id "$APPLE_API_KEY_ID" \
    --issuer "$APPLE_API_ISSUER_ID" \
    --wait
xcrun stapler staple "$dmg_path"
xcrun stapler validate "$dmg_path"
spctl --assess --type open --context context:primary-signature --verbose=2 "$dmg_path"
