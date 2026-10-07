#!/bin/sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
test_dir=$(mktemp -d)
app_dir="$test_dir/Mac Input Lock.app"
appcast_path="$test_dir/appcast.xml"
trap 'rm -rf "$test_dir"' EXIT INT TERM

mkdir -p "$app_dir/Contents"
cp "$project_dir/Resources/Info.plist" "$app_dir/Contents/Info.plist"
plutil -replace CFBundleShortVersionString -string "1.3.2" "$app_dir/Contents/Info.plist"
plutil -replace CFBundleVersion -string "23" "$app_dir/Contents/Info.plist"

write_appcast() {
    build_number=$1
    cat > "$appcast_path" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" version="2.0">
  <channel>
    <item>
      <sparkle:version>$build_number</sparkle:version>
      <sparkle:shortVersionString>1.3.2</sparkle:shortVersionString>
    </item>
  </channel>
</rss>
EOF
}

write_appcast "23"
"$project_dir/Scripts/verify-update-metadata.sh" "$app_dir" "$appcast_path"

write_appcast "132"
if "$project_dir/Scripts/verify-update-metadata.sh" "$app_dir" "$appcast_path" >/dev/null 2>&1; then
    echo "Expected mismatched build numbers to fail validation." >&2
    exit 1
fi

echo "Update metadata validation tests passed."
