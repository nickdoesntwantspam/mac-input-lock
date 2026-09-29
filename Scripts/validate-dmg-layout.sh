#!/bin/sh
set -eu

dmg_path=${1:-}
test -f "$dmg_path" || { echo "Usage: $0 <path-to.dmg>" >&2; exit 1; }

device=
cleanup() {
    if [ -n "$device" ]; then
        hdiutil detach "$device" -quiet || true
    fi
}
trap cleanup EXIT INT TERM

attach_output=$(hdiutil attach "$dmg_path" -readonly -noverify -noautoopen -nobrowse)
device=$(printf '%s\n' "$attach_output" | awk '/\/Volumes\// { print $1; exit }')
mount_dir=$(printf '%s\n' "$attach_output" | sed -n 's|^.*[[:space:]]\(/Volumes/.*\)$|\1|p' | tail -n 1)
test -n "$device" && test -n "$mount_dir" || { echo "Could not mount DMG." >&2; exit 1; }

test -d "$mount_dir/Mac Input Lock.app"
test -L "$mount_dir/Applications"
test -f "$mount_dir/.DS_Store"
test -f "$mount_dir/Mac Input Lock.app/Contents/Resources/InstallerBackground.png"

unexpected=$(find "$mount_dir" -mindepth 1 -maxdepth 1 \
    ! -name '.DS_Store' \
    ! -name 'Applications' \
    ! -name 'Mac Input Lock.app' \
    -print)
if [ -n "$unexpected" ]; then
    echo "Unexpected item(s) in DMG root:" >&2
    printf '%s\n' "$unexpected" >&2
    exit 1
fi

echo "DMG layout is clean: $dmg_path"
