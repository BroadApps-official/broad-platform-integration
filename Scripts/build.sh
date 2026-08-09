#!/usr/bin/env bash

set -euo pipefail

platform_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
example_root="$platform_root/Examples/BroadAppTemplate"
derived_data="$platform_root/.build/DerivedData"
swift_module_cache="$platform_root/.build/SwiftModuleCache"
swiftpm_cache="$platform_root/.build/SwiftPMCache"
swiftpm_config="$platform_root/.build/SwiftPMConfig"
swiftpm_security="$platform_root/.build/SwiftPMSecurity"
ios_simulator_sdk="$(xcrun --sdk iphonesimulator --show-sdk-path)"
simulator_arch="$(uname -m)"
translation_state="$(sysctl -in sysctl.proc_translated 2>/dev/null || true)"

mkdir -p \
    "$swift_module_cache" \
    "$swiftpm_cache" \
    "$swiftpm_config" \
    "$swiftpm_security"
export CLANG_MODULE_CACHE_PATH="$swift_module_cache"
export SWIFT_MODULECACHE_PATH="$swift_module_cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$swift_module_cache"

xcodebuild_package_arguments=(
    -clonedSourcePackagesDirPath "$derived_data/SourcePackages"
    -packageCachePath "$derived_data/PackageCache"
)

if [[ "$simulator_arch" == "x86_64" && "$translation_state" == "1" ]]; then
    simulator_arch="arm64"
fi

if [[ "$simulator_arch" != "arm64" && "$simulator_arch" != "x86_64" ]]; then
    echo "Unsupported simulator architecture: $simulator_arch"
    exit 1
fi

"$platform_root/Scripts/generate_example.sh"

echo "[build 1/4] Swift Package, Debug Simulator, strict concurrency"
swift build \
    --quiet \
    --package-path "$platform_root" \
    --cache-path "$swiftpm_cache" \
    --config-path "$swiftpm_config" \
    --security-path "$swiftpm_security" \
    --configuration debug \
    --triple "${simulator_arch}-apple-ios17.0-simulator" \
    --sdk "$ios_simulator_sdk" \
    -Xswiftc -strict-concurrency=complete \
    -Xswiftc -warnings-as-errors

echo "[build 2/4] Example, Debug Simulator"
xcodebuild \
    -quiet \
    "${xcodebuild_package_arguments[@]}" \
    -project "$example_root/BroadAppTemplate.xcodeproj" \
    -scheme BroadAppTemplate \
    -configuration Debug \
    -destination 'generic/platform=iOS Simulator' \
    -derivedDataPath "$derived_data" \
    CODE_SIGNING_ALLOWED=NO \
    build

echo "[build 3/4] Example, Release Simulator"
xcodebuild \
    -quiet \
    "${xcodebuild_package_arguments[@]}" \
    -project "$example_root/BroadAppTemplate.xcodeproj" \
    -scheme BroadAppTemplate \
    -configuration Release \
    -destination 'generic/platform=iOS Simulator' \
    -derivedDataPath "$derived_data" \
    CODE_SIGNING_ALLOWED=NO \
    build

echo "[build 4/4] Example, Release generic iOS device (unsigned)"
xcodebuild \
    -quiet \
    "${xcodebuild_package_arguments[@]}" \
    -project "$example_root/BroadAppTemplate.xcodeproj" \
    -scheme BroadAppTemplate \
    -configuration Release \
    -destination 'generic/platform=iOS' \
    -derivedDataPath "$derived_data" \
    CODE_SIGNING_ALLOWED=NO \
    build

device_app="$derived_data/Build/Products/Release-iphoneos/BroadAppTemplate.app"
bash "$platform_root/Scripts/check_privacy_manifest.sh" "$device_app"
