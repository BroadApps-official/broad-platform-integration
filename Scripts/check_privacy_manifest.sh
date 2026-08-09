#!/usr/bin/env bash

set -euo pipefail

platform_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
manifest="$platform_root/Sources/BroadCore/Resources/PrivacyInfo.xcprivacy"
expected_category="NSPrivacyAccessedAPICategoryUserDefaults"
expected_reasons="CA92.1,1C8F.1"

matches_source_manifest() {
    local candidate="$1"
    local candidate_json

    plutil -lint "$candidate" >/dev/null || return 1
    candidate_json="$(plutil -convert json -o - "$candidate")" || return 1
    SOURCE_MANIFEST_JSON="$manifest_json" \
        CANDIDATE_MANIFEST_JSON="$candidate_json" \
        /usr/bin/ruby -rjson -e '
          source = JSON.parse(ENV.fetch("SOURCE_MANIFEST_JSON"))
          candidate = JSON.parse(ENV.fetch("CANDIDATE_MANIFEST_JSON"))
          exit(source == candidate ? 0 : 1)
        ' >/dev/null 2>&1
}

if [[ ! -f "$manifest" ]]; then
    echo "BroadCore privacy manifest is missing: $manifest"
    exit 1
fi

plutil -lint "$manifest" >/dev/null

manifest_json="$(plutil -convert json -o - "$manifest")"
if ! EXPECTED_CATEGORY="$expected_category" EXPECTED_REASONS="$expected_reasons" \
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
      entry = matching_entries.first
      reasons = entry["NSPrivacyAccessedAPITypeReasons"]
      expected = ENV.fetch("EXPECTED_REASONS").split(",")
      abort "UserDefaults reasons must equal the approved set" unless reasons.is_a?(Array) && reasons.length == reasons.uniq.length && reasons.sort == expected.sort
    '; then
    echo "BroadCore privacy manifest has an invalid semantic contract."
    exit 1
fi

if (($# > 0)); then
    built_product="$1"
    if [[ ! -d "$built_product" ]]; then
        echo "Built app does not exist for privacy verification: $built_product"
        exit 1
    fi

    bundled_manifest=""
    bundled_broad_core_manifest_count=0
    bundled_manifest_count=0
    while IFS= read -r -d '' candidate; do
        bundled_manifest_count=$((bundled_manifest_count + 1))
        if ! plutil -lint "$candidate" >/dev/null; then
            echo "Built app contains an invalid privacy manifest:"
            echo "${candidate#"$built_product"/}"
            exit 1
        fi
        if [[ "$(basename "$(dirname "$candidate")")" == \
            "BroadAppsIOSPlatform_BroadCore.bundle" ]]; then
            bundled_broad_core_manifest_count=$((bundled_broad_core_manifest_count + 1))
            bundled_manifest="$candidate"
        fi
    done < <(find "$built_product" -type f -name PrivacyInfo.xcprivacy -print0)

    if ((bundled_manifest_count == 0)); then
        echo "Built app contains no privacy manifests: $built_product"
        exit 1
    fi
    if ((bundled_broad_core_manifest_count != 1)) || [[ -z "$bundled_manifest" ]]; then
        echo "Built app must contain exactly one canonical BroadCore privacy manifest:"
        echo "$built_product"
        exit 1
    fi
    if ! matches_source_manifest "$bundled_manifest"; then
        echo "Bundled BroadCore privacy manifest differs from the current source contract:"
        echo "${bundled_manifest#"$built_product"/}"
        exit 1
    fi
    echo "BroadCore privacy manifest is valid and bundled: ${bundled_manifest#"$built_product"/}"
else
    echo "Privacy manifest source contract passed."
fi
