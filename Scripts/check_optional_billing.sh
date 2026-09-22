#!/usr/bin/env bash
set -euo pipefail
platform_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
example_root="$platform_root/Examples/BroadAppleOnlyTemplate"
derived_data="$platform_root/.build/AppleOnlyDerivedData"
xcodegen="$platform_root/.build/tooling/xcodegen-2.45.4/xcodegen/bin/xcodegen"
if [[ ! -x "$xcodegen" ]]; then bash "$platform_root/Scripts/install_build_tools.sh"; fi
"$xcodegen" generate --spec "$example_root/project.yml" --project "$example_root"
if rg -n 'BroadRUBilling|RUCatalog|RUCheckout|ru_pay|ru-billing|ukassa|\bsbp\b' "$example_root/Sources" "$example_root/project.yml"; then
    echo 'The Apple-only example must not contain an RU dependency or handler.'
    exit 1
fi
for configuration in Debug Release; do
    destination='generic/platform=iOS Simulator'
    if [[ "$configuration" == Release ]]; then destination='generic/platform=iOS'; fi
    xcodebuild -quiet -project "$example_root/BroadAppleOnlyTemplate.xcodeproj" -scheme BroadAppleOnlyTemplate -configuration "$configuration" -destination "$destination" -derivedDataPath "$derived_data" CODE_SIGNING_ALLOWED=NO build
done
python3 "$platform_root/Scripts/check_optional_billing.py" "$derived_data" "$example_root"
