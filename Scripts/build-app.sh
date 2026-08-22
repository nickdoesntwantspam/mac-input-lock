#!/bin/sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
configuration=${CONFIGURATION:-release}
app_dir="$project_dir/dist/Mac Input Lock.app"
assembly_dir=$(mktemp -d)
build_app_dir="$assembly_dir/Mac Input Lock.app"
trap 'rm -rf "$assembly_dir"' EXIT INT TERM
universal=${UNIVERSAL:-0}

version=${VERSION:-}
if [ -z "$version" ]; then
    version=$(git -C "$project_dir" describe --tags --match 'v[0-9]*' --exact-match 2>/dev/null | sed 's/^v//' || true)
fi
version=${version:-0.0.0}

build_number=${BUILD_NUMBER:-}
if [ -z "$build_number" ]; then
    build_number=$(git -C "$project_dir" rev-list --count HEAD 2>/dev/null || true)
fi
build_number=${build_number:-1}

if [ -n "${SIGNING_IDENTITY:-}" ]; then
    signing_identity=$SIGNING_IDENTITY
else
    signing_identity=$(security find-identity -v -p codesigning 2>/dev/null \
        | sed -n 's/.*"\(Developer ID Application:[^"]*\)".*/\1/p' \
        | head -n 1)
    if [ -z "$signing_identity" ]; then
        signing_identity=$(security find-identity -v -p codesigning 2>/dev/null \
            | sed -n 's/.*"\(Apple Development:[^"]*\)".*/\1/p' \
            | head -n 1)
    fi
    if [ -z "$signing_identity" ]; then
        signing_identity=$(security find-identity -v -p codesigning 2>/dev/null \
            | sed -n 's/.*"\(Apple Distribution:[^"]*\)".*/\1/p' \
            | head -n 1)
    fi
    signing_identity=${signing_identity:--}
fi

if [ "${REQUIRE_DEVELOPER_ID:-0}" = "1" ]; then
    case "$signing_identity" in
        "Developer ID Application:"*) ;;
        *) echo "A Developer ID Application signing identity is required." >&2; exit 1 ;;
    esac
fi

cd "$project_dir"
if [ "$universal" = "1" ]; then
    swift build -c "$configuration" --arch arm64 --arch x86_64
    binary_dir=$(swift build -c "$configuration" --arch arm64 --arch x86_64 --show-bin-path)
else
    swift build -c "$configuration"
    binary_dir=$(swift build -c "$configuration" --show-bin-path)
fi

mkdir -p "$build_app_dir/Contents/MacOS" "$build_app_dir/Contents/Resources"
cp "$binary_dir/MacInputLock" "$build_app_dir/Contents/MacOS/MacInputLock"
cp "$project_dir/Resources/Info.plist" "$build_app_dir/Contents/Info.plist"
cp "$project_dir/Resources/MacInputLock.icns" "$build_app_dir/Contents/Resources/MacInputLock.icns"
plutil -replace CFBundleShortVersionString -string "$version" "$build_app_dir/Contents/Info.plist"
plutil -replace CFBundleVersion -string "$build_number" "$build_app_dir/Contents/Info.plist"

xattr -cr "$build_app_dir"
if [ "$signing_identity" = "-" ]; then
    codesign --force --options runtime --sign - "$build_app_dir"
else
    codesign --force --options runtime --timestamp --sign "$signing_identity" "$build_app_dir"
fi

codesign --verify --deep --strict "$build_app_dir"
rm -rf "$app_dir"
mkdir -p "$(dirname "$app_dir")"
ditto --norsrc --noextattr "$build_app_dir" "$app_dir"
echo "$app_dir"
