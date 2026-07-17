#!/bin/sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tag=$(git -C "$project_dir" describe --tags --match 'v[0-9]*' --exact-match 2>/dev/null || true)
case "$tag" in
    v[0-9]*) ;;
    *) echo "Release builds must run from an exact v* tag." >&2; exit 1 ;;
esac
version=${tag#v}

: "${SIGNING_IDENTITY:?Set SIGNING_IDENTITY to a Developer ID Application certificate.}"
case "$SIGNING_IDENTITY" in
    "Developer ID Application:"*) ;;
    *) echo "SIGNING_IDENTITY must be a Developer ID Application certificate." >&2; exit 1 ;;
esac

cd "$project_dir"
swift test
VERSION="$version" UNIVERSAL=1 REQUIRE_DEVELOPER_ID=1 ./Scripts/build-app.sh
VERSION="$version" ./Scripts/create-dmg.sh
./Scripts/notarize.sh "$project_dir/dist/Mac-Input-Lock-$version.dmg"
shasum -a 256 "$project_dir/dist/Mac-Input-Lock-$version.dmg" \
    | sed "s|$project_dir/dist/||" \
    > "$project_dir/dist/Mac-Input-Lock-$version.dmg.sha256"

file "$project_dir/dist/Mac Input Lock.app/Contents/MacOS/MacInputLock" | grep -q 'universal binary'
codesign --verify --deep --strict --verbose=2 "$project_dir/dist/Mac Input Lock.app"
