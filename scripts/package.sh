#!/bin/bash
set -euo pipefail

version=${1:-1.0.0}
build_number=${AUTODOCK_BUILD_NUMBER:-1}
if [[ $# -gt 1 || ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
then
    printf '%s\n' '用法：bash scripts/package.sh 1.0.0' >&2
    exit 1
fi
if [[ ! "$build_number" =~ ^[0-9]+$ ]]
then
    printf '%s\n' 'AUTODOCK_BUILD_NUMBER 必须为整数' >&2
    exit 1
fi

project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
output_dir=${AUTODOCK_OUTPUT_DIR:-$project_root/dist}
mkdir -p -- "$output_dir"
output_dir=$(cd -- "$output_dir" && pwd)
derived_data="$output_dir/build-$version"
staging_dir=$(mktemp -d "${TMPDIR:-/tmp}/autodock-package.XXXXXX")
trap 'rm -rf -- "$staging_dir"' EXIT

/usr/bin/xcodebuild \
    -project "$project_root/AutoDock.xcodeproj" \
    -scheme 'AutoDock' \
    -configuration 'Release' \
    -destination 'generic/platform=macOS' \
    -derivedDataPath "$derived_data" \
    ARCHS='arm64 x86_64' \
    ONLY_ACTIVE_ARCH=NO \
    MACOSX_DEPLOYMENT_TARGET=13.0 \
    MARKETING_VERSION="$version" \
    CURRENT_PROJECT_VERSION="$build_number" \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY='-' \
    CODE_SIGNING_ALLOWED=YES \
    ENABLE_HARDENED_RUNTIME=NO \
    build

/usr/bin/ditto "$derived_data/Build/Products/Release/AutoDock.app" "$staging_dir/AutoDock.app"
/usr/bin/lipo "$staging_dir/AutoDock.app/Contents/MacOS/AutoDock" -verify_arch arm64
/usr/bin/lipo "$staging_dir/AutoDock.app/Contents/MacOS/AutoDock" -verify_arch x86_64
/usr/bin/codesign --force --sign '-' --identifier 'com.autodock.AutoDock' "$staging_dir/AutoDock.app"
/usr/bin/codesign --verify --strict "$staging_dir/AutoDock.app"

zip_name="AutoDock-$version-universal.zip"
dmg_name="AutoDock-$version-universal.dmg"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$staging_dir/AutoDock.app" "$output_dir/$zip_name"
ln -s '/Applications' "$staging_dir/Applications"
/usr/bin/hdiutil create \
    -volname 'AutoDock' \
    -srcfolder "$staging_dir" \
    -format 'UDZO' \
    -fs 'HFS+' \
    -ov "$output_dir/$dmg_name"

(
    cd -- "$output_dir"
    /usr/bin/shasum -a 256 "$zip_name" "$dmg_name" > "AutoDock-$version-SHA256SUMS.txt"
)
printf '已生成安装包：%s\n' "$output_dir"
