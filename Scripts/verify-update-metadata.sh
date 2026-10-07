#!/bin/sh
set -eu

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <app bundle> <appcast.xml>" >&2
    exit 2
fi

app_dir=$1
appcast_path=$2
info_plist="$app_dir/Contents/Info.plist"

test -f "$info_plist" || { echo "Missing app Info.plist: $info_plist" >&2; exit 1; }
test -f "$appcast_path" || { echo "Missing appcast: $appcast_path" >&2; exit 1; }

app_version=$(plutil -extract CFBundleShortVersionString raw -o - "$info_plist")
app_build=$(plutil -extract CFBundleVersion raw -o - "$info_plist")
feed_version=$(xmllint --xpath 'string(//*[local-name()="shortVersionString"][1])' "$appcast_path")
feed_build=$(xmllint --xpath 'string(//*[local-name()="version"][1])' "$appcast_path")

if [ "$app_version" != "$feed_version" ]; then
    echo "Update version mismatch: app is $app_version, appcast is $feed_version." >&2
    exit 1
fi

if [ "$app_build" != "$feed_build" ]; then
    echo "Update build mismatch: app is $app_build, appcast is $feed_build." >&2
    exit 1
fi

echo "Update metadata matches Mac Input Lock $app_version ($app_build)."
