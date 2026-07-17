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
dmg_path="$project_dir/dist/Mac-Input-Lock-$version.dmg"
stage_dir=$(mktemp -d)
trap 'rm -rf "$stage_dir"' EXIT

test -d "$app_dir" || { echo "Build the app before creating the DMG." >&2; exit 1; }
ditto "$app_dir" "$stage_dir/Mac Input Lock.app"
ln -s /Applications "$stage_dir/Applications"
xattr -cr "$stage_dir"
rm -f "$dmg_path" "$dmg_path.sha256"
hdiutil create -quiet -volname "Mac Input Lock" -srcfolder "$stage_dir" -ov -format UDZO "$dmg_path"

if [ -n "${SIGNING_IDENTITY:-}" ] && [ "$SIGNING_IDENTITY" != "-" ]; then
    codesign --force --timestamp --sign "$SIGNING_IDENTITY" "$dmg_path"
fi

shasum -a 256 "$dmg_path" | sed "s|$project_dir/dist/||" > "$dmg_path.sha256"
echo "$dmg_path"
