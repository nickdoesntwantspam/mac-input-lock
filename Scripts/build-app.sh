#!/bin/sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
configuration=${CONFIGURATION:-release}
app_dir="$project_dir/dist/Mac Input Lock.app"
assembly_dir=$(mktemp -d)
build_app_dir="$assembly_dir/Mac Input Lock.app"
trap 'rm -rf "$assembly_dir"' EXIT INT TERM
universal=${UNIVERSAL:-0}

strip_disallowed_xattrs() {
    xattr -cr "$1"
    find "$1" -exec xattr -d com.apple.FinderInfo {} \; 2>/dev/null || true
    find "$1" -exec xattr -d com.apple.ResourceFork {} \; 2>/dev/null || true
}

verify_bundle() {
    if codesign --verify --deep --strict "$1"; then
        return
    fi

    # iCloud Drive can immediately reattach empty Finder metadata to bundles
    # stored under Documents. Accept that local-only mutation if the signature
    # itself still verifies; CI and release validation always require strict.
    if xattr -p 'com.apple.fileprovider.fpfs#P' "$1" >/dev/null 2>&1; then
        codesign --verify --deep "$1"
        echo "Warning: strict verification was relaxed for an iCloud-managed local build." >&2
        return
    fi

    return 1
}

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

mkdir -p "$build_app_dir/Contents/MacOS" "$build_app_dir/Contents/Resources" "$build_app_dir/Contents/Frameworks"
cp "$binary_dir/MacInputLock" "$build_app_dir/Contents/MacOS/MacInputLock"
ditto "$binary_dir/Sparkle.framework" "$build_app_dir/Contents/Frameworks/Sparkle.framework"
cp "$project_dir/Resources/Info.plist" "$build_app_dir/Contents/Info.plist"
cp "$project_dir/Resources/MacInputLock.icns" "$build_app_dir/Contents/Resources/MacInputLock.icns"
cp "$project_dir/.build/checkouts/Sparkle/LICENSE" "$build_app_dir/Contents/Resources/Sparkle-LICENSE.txt"
chmod 644 "$build_app_dir/Contents/Resources/Sparkle-LICENSE.txt"
plutil -replace CFBundleShortVersionString -string "$version" "$build_app_dir/Contents/Info.plist"
plutil -replace CFBundleVersion -string "$build_number" "$build_app_dir/Contents/Info.plist"

strip_disallowed_xattrs "$build_app_dir"
if [ "$signing_identity" = "-" ]; then
    codesign --force --deep --options runtime \
        --preserve-metadata=identifier,entitlements,flags \
        --sign - "$build_app_dir/Contents/Frameworks/Sparkle.framework"
    codesign --force --options runtime \
        --entitlements "$project_dir/Resources/Debug.entitlements" \
        --sign - "$build_app_dir"
else
    codesign --force --deep --options runtime --timestamp \
        --preserve-metadata=identifier,entitlements,flags \
        --sign "$signing_identity" "$build_app_dir/Contents/Frameworks/Sparkle.framework"
    codesign --force --options runtime --timestamp --sign "$signing_identity" "$build_app_dir"
fi

codesign --verify --deep --strict "$build_app_dir"
rm -rf "$app_dir"
mkdir -p "$(dirname "$app_dir")"
ditto --norsrc --noextattr "$build_app_dir" "$app_dir"
strip_disallowed_xattrs "$app_dir"
verify_bundle "$app_dir"
echo "$app_dir"
