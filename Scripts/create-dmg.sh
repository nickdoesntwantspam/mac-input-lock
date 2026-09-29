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
volume_name="Mac Input Lock $version"
stage_dir=$(mktemp -d)
image_dir=$(mktemp -d)
rw_dmg="$image_dir/source.dmg"
device=
mount_dir=
cleanup() {
    if [ -n "$device" ]; then
        hdiutil detach "$device" -quiet || true
    fi
    rm -rf "$stage_dir" "$image_dir"
}
trap cleanup EXIT INT TERM

test -d "$app_dir" || { echo "Build the app before creating the DMG." >&2; exit 1; }
ditto "$app_dir" "$stage_dir/Mac Input Lock.app"
ln -s /Applications "$stage_dir/Applications"
test -f "$stage_dir/Mac Input Lock.app/Contents/Resources/InstallerBackground.png" || {
    echo "App bundle is missing InstallerBackground.png; rebuild the app." >&2
    exit 1
}
xattr -cr "$stage_dir"
rm -f "$dmg_path" "$dmg_path.sha256"
hdiutil create -quiet -volname "$volume_name" -srcfolder "$stage_dir" -ov -format UDRW "$rw_dmg"
attach_output=$(hdiutil attach "$rw_dmg" -readwrite -noverify -noautoopen)
device=$(printf '%s\n' "$attach_output" | awk '/\/Volumes\// { print $1; exit }')
mount_dir=$(printf '%s\n' "$attach_output" | sed -n 's|^.*[[:space:]]\(/Volumes/.*\)$|\1|p' | tail -n 1)
test -n "$device" && test -n "$mount_dir" || { echo "Could not mount the writable DMG." >&2; exit 1; }
touch "$mount_dir/.DS_Store"

osascript <<EOF
tell application "Finder"
    delay 1
    tell disk "$volume_name"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set pathbar visible of container window to false
        set bounds of container window to {100, 100, 760, 520}
        set theViewOptions to the icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 112
        set text size of theViewOptions to 14
        set backgroundFile to POSIX file "$mount_dir/Mac Input Lock.app/Contents/Resources/InstallerBackground.png" as alias
        set background picture of theViewOptions to backgroundFile
        set position of item "Mac Input Lock.app" of container window to {175, 225}
        set position of item "Applications" of container window to {485, 225}
        update without registering applications
        delay 2
        close
    end tell
end tell
EOF

sync
for attempt in 1 2 3 4 5; do
    if [ -s "$mount_dir/.DS_Store" ]; then
        break
    fi
    sleep 1
done
test -s "$mount_dir/.DS_Store" || { echo "Finder did not save the styled DMG layout." >&2; exit 1; }
rm -rf "$mount_dir/.fseventsd" "$mount_dir/.Spotlight-V100" "$mount_dir/.Trashes"
hdiutil detach "$device" -quiet
device=
hdiutil convert -quiet "$rw_dmg" -format UDZO -o "$dmg_path"
"$project_dir/Scripts/validate-dmg-layout.sh" "$dmg_path"

if [ -n "${SIGNING_IDENTITY:-}" ] && [ "$SIGNING_IDENTITY" != "-" ]; then
    codesign --force --timestamp --sign "$SIGNING_IDENTITY" "$dmg_path"
fi

shasum -a 256 "$dmg_path" | sed "s|$project_dir/dist/||" > "$dmg_path.sha256"
echo "$dmg_path"
