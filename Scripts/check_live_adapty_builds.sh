#!/usr/bin/env bash

set -euo pipefail

platform_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
example_root="$platform_root/Examples/BroadAppTemplate"
derived_data="$platform_root/.build/LiveAdaptyDerivedData"
xcodebuild_package_arguments=(
    -clonedSourcePackagesDirPath "$derived_data/SourcePackages"
    -packageCachePath "$derived_data/PackageCache"
)

bash "$platform_root/Scripts/generate_example.sh"

echo "[live 1/2] Build 5013 Adapty configuration (no app launch, no purchase)"
xcodebuild \
    -quiet \
    "${xcodebuild_package_arguments[@]}" \
    -project "$example_root/BroadAppTemplate.xcodeproj" \
    -scheme BroadAppTemplateLiveAdapty5013 \
    -configuration LiveAdapty5013 \
    -destination 'generic/platform=iOS Simulator' \
    -derivedDataPath "$derived_data" \
    CODE_SIGNING_ALLOWED=NO \
    build

echo "[live 2/2] Build 5109Codex Adapty configuration (no app launch, no purchase)"
xcodebuild \
    -quiet \
    "${xcodebuild_package_arguments[@]}" \
    -project "$example_root/BroadAppTemplate.xcodeproj" \
    -scheme BroadAppTemplateLiveAdapty5109Codex \
    -configuration LiveAdapty5109Codex \
    -destination 'generic/platform=iOS Simulator' \
    -derivedDataPath "$derived_data" \
    CODE_SIGNING_ALLOWED=NO \
    build

echo "Both tracked live Adapty configurations compile successfully."
