#!/usr/bin/env bash

set -euo pipefail

platform_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
expected_category="NSPrivacyAccessedAPICategoryUserDefaults"
expected_reasons="CA92.1,1C8F.1"

validate_broad_core_manifest() {
    local candidate="$1"
    local manifest_json

    plutil -lint "$candidate" >/dev/null
    manifest_json="$(plutil -convert json -o - "$candidate")"
    EXPECTED_CATEGORY="$expected_category" \
        EXPECTED_REASONS="$expected_reasons" \
        MANIFEST_JSON="$manifest_json" \
        /usr/bin/ruby -rjson -e '
          manifest = JSON.parse(ENV.fetch("MANIFEST_JSON"))
          abort "NSPrivacyTracking must be false" unless manifest["NSPrivacyTracking"] == false
          abort "NSPrivacyTrackingDomains must be empty" unless manifest["NSPrivacyTrackingDomains"] == []
          abort "NSPrivacyCollectedDataTypes must be empty" unless manifest["NSPrivacyCollectedDataTypes"] == []
          entries = manifest["NSPrivacyAccessedAPITypes"]
          abort "NSPrivacyAccessedAPITypes must be an array" unless entries.is_a?(Array)
          matching_entries = entries.select { |item| item["NSPrivacyAccessedAPIType"] == ENV.fetch("EXPECTED_CATEGORY") }
          abort "Exactly one UserDefaults declaration is required" unless entries.length == 1 && matching_entries.length == 1
          reasons = matching_entries.first["NSPrivacyAccessedAPITypeReasons"]
          expected = ENV.fetch("EXPECTED_REASONS").split(",")
          abort "UserDefaults reasons must equal the approved set" unless reasons.is_a?(Array) && reasons.length == reasons.uniq.length && reasons.sort == expected.sort
        '
}

if ! rg -q --multiline -- \
    'broad-core-ios\.git",[[:space:]]*exact:[[:space:]]*"1\.0\.0"' \
    "$platform_root/Package.swift"; then
    echo "Integration Package.swift must pin BroadCore 1.0.0 exactly."
    exit 1
fi

if (($# == 0)); then
    echo "BroadCore 1.0.0 privacy contract is delegated to the released module gate."
    exit 0
fi

built_product="$1"
if [[ ! -d "$built_product" ]]; then
    echo "Built app does not exist for privacy verification: $built_product"
    exit 1
fi

bundled_manifest_count=0
broad_core_manifests=()
while IFS= read -r -d '' candidate; do
    bundled_manifest_count=$((bundled_manifest_count + 1))
    if ! plutil -lint "$candidate" >/dev/null; then
        echo "Built app contains an invalid privacy manifest:"
        echo "${candidate#"$built_product"/}"
        exit 1
    fi
    if [[ "$(basename "$(dirname "$candidate")")" == *_BroadCore.bundle ]]; then
        broad_core_manifests+=("$candidate")
    fi
done < <(find "$built_product" -type f -name PrivacyInfo.xcprivacy -print0)

if ((bundled_manifest_count == 0)); then
    echo "Built app contains no privacy manifests: $built_product"
    exit 1
fi
if ((${#broad_core_manifests[@]} != 1)); then
    echo "Built app must contain exactly one released BroadCore privacy manifest:"
    echo "$built_product"
    exit 1
fi
if ! validate_broad_core_manifest "${broad_core_manifests[0]}"; then
    echo "Bundled BroadCore privacy manifest violates the released semantic contract:"
    echo "${broad_core_manifests[0]#"$built_product"/}"
    exit 1
fi

echo "BroadCore privacy manifest is valid and bundled: ${broad_core_manifests[0]#"$built_product"/}"
