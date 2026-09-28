#!/bin/sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
version=${VERSION:-}
if [ -z "$version" ]; then
    version=$(git -C "$project_dir" describe --tags --match 'v[0-9]*' --exact-match 2>/dev/null | sed 's/^v//' || true)
fi
if [ -z "$version" ]; then
    echo "VERSION or an exact v* Git tag is required." >&2
    exit 1
fi

app_dir="$project_dir/dist/Mac Input Lock.app"
archive_name="Mac-Input-Lock-$version.zip"
archive_path="$project_dir/dist/$archive_name"
appcast_path="$project_dir/dist/appcast.xml"
checksum_path="$archive_path.sha256"
sparkle_bin="$project_dir/.build/artifacts/sparkle/Sparkle/bin"
generate_appcast="$sparkle_bin/generate_appcast"
sign_update="$sparkle_bin/sign_update"
update_dir=$(mktemp -d)
trap 'rm -rf "$update_dir"' EXIT INT TERM

test -d "$app_dir" || { echo "Build the app before creating an update." >&2; exit 1; }
test -x "$generate_appcast" || { echo "Run swift package resolve before creating an update." >&2; exit 1; }
test -x "$sign_update" || { echo "Sparkle's signing tools are unavailable." >&2; exit 1; }

rm -f "$archive_path" "$checksum_path" "$appcast_path"
ditto -c -k --sequesterRsrc --keepParent "$app_dir" "$archive_path"
cp "$archive_path" "$update_dir/$archive_name"

set -- \
    --download-url-prefix "https://github.com/nickdoesntwantspam/mac-input-lock/releases/download/v$version/" \
    --link "https://macinputlock.com/" \
    --maximum-deltas 0 \
    --maximum-versions 1 \
    -o appcast.xml \
    .

if [ -n "${SPARKLE_PRIVATE_KEY:-}" ]; then
    (cd "$update_dir" && printf '%s' "$SPARKLE_PRIVATE_KEY" | "$generate_appcast" --ed-key-file - "$@")
else
    (cd "$update_dir" && "$generate_appcast" --account com.nicholaswilliams.MacInputLock "$@")
fi

grep -q 'sparkle:edSignature=' "$update_dir/appcast.xml"
grep -q 'sparkle-signatures:' "$update_dir/appcast.xml"
archive_signature=$(sed -n 's/.*sparkle:edSignature="\([^"]*\)".*/\1/p' "$update_dir/appcast.xml")
test -n "$archive_signature"

if [ -n "${SPARKLE_PRIVATE_KEY:-}" ]; then
    printf '%s' "$SPARKLE_PRIVATE_KEY" | "$sign_update" --ed-key-file - --verify "$archive_path" "$archive_signature"
    printf '%s' "$SPARKLE_PRIVATE_KEY" | "$sign_update" --ed-key-file - --verify "$update_dir/appcast.xml"
else
    "$sign_update" --account com.nicholaswilliams.MacInputLock --verify "$archive_path" "$archive_signature"
    "$sign_update" --account com.nicholaswilliams.MacInputLock --verify "$update_dir/appcast.xml"
fi

cp "$update_dir/appcast.xml" "$appcast_path"
shasum -a 256 "$archive_path" | sed "s|$project_dir/dist/||" > "$checksum_path"

echo "$archive_path"
echo "$appcast_path"
