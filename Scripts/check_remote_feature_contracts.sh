#!/usr/bin/env bash

set -euo pipefail

platform_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
failure_count=0

require_pattern() {
    local description="$1"
    local file="$2"
    local pattern="$3"
    local status=0

    rg -q --pcre2 --multiline "$pattern" "$file" || status=$?
    case "$status" in
        0)
            echo "PASS: $description"
            ;;
        1)
            echo "FAIL: $description"
            echo "      $file"
            failure_count=$((failure_count + 1))
            ;;
        *)
            echo "Remote feature integration check could not run: $description"
            exit "$status"
            ;;
    esac
}

forbid_pattern() {
    local description="$1"
    local pattern="$2"
    shift 2
    local output=""
    local status=0

    output="$(rg -n --pcre2 --multiline "$pattern" "$@")" || status=$?
    case "$status" in
        0)
            echo "FAIL: $description"
            echo "$output"
            failure_count=$((failure_count + 1))
            ;;
        1)
            echo "PASS: $description"
            ;;
        *)
            echo "Remote feature integration check could not run: $description"
            exit "$status"
            ;;
    esac
}

example_environment_file="$platform_root/Examples/BroadAppTemplate/BroadAppTemplate/Infrastructure/Monetization/ExampleMonetizationEnvironment.swift"

echo "Remote Config integration contract matrix"

require_pattern \
    "Integration pins the released BroadMonetization contract" \
    "$platform_root/Package.swift" \
    'broad-monetization-ios\.git",[[:space:]]*exact:[[:space:]]*"1\.0\.0"'

require_pattern \
    "Host example connects BroadMonetization directly" \
    "$platform_root/Examples/BroadAppTemplate/project.yml" \
    'BroadMonetization:(?s:.*?)url:[[:space:]]+https://github\.com/BroadApps-official/broad-monetization-ios\.git(?s:.*?)exactVersion:[[:space:]]+1\.0\.0(?s:.*?)package:[[:space:]]+BroadMonetization(?s:.*?)product:[[:space:]]+BroadMonetization'

require_pattern \
    "Integration pins the released BroadUIFlows contract" \
    "$platform_root/Package.swift" \
    'broad-ui-flows-ios\.git",[[:space:]]*exact:[[:space:]]*"1\.0\.0"'

require_pattern \
    "Host example connects BroadUIFlows directly" \
    "$platform_root/Examples/BroadAppTemplate/project.yml" \
    'BroadUIFlows:(?s:.*?)url:[[:space:]]+https://github\.com/BroadApps-official/broad-ui-flows-ios\.git(?s:.*?)exactVersion:[[:space:]]+1\.0\.0(?s:.*?)package:[[:space:]]+BroadUIFlows(?s:.*?)product:[[:space:]]+BroadUIFlows'

require_pattern \
    "BroadUIFlows Special Offer UI contract has release evidence" \
    "$platform_root/Compatibility/current.yml" \
    'broad-ui-flows-ios/releases/tag/1\.0\.0'

require_pattern \
    "Host template unlocks RU Billing manual override only in DEBUG" \
    "$example_environment_file" \
    '#if[[:space:]]+DEBUG(?s:.*?)RUBillingDebugOverrideStore\(allowsManualOverrides:[[:space:]]*true\)(?s:.*?)#else(?s:.*?)RUBillingDebugOverrideStore\(\)(?s:.*?)#endif'

forbid_pattern \
    "Integration contains no second client-side experiment randomizer" \
    '(?i)\b(ExperimentAssignment|CohortAssignment|SegmentAssignment|ExperimentRandomizer|CohortRandomizer|ClientSideRandomizer|arc4random|randomElement)\b' \
    "$platform_root/Examples/BroadAppTemplate/BroadAppTemplate" \
    --glob '*.swift'

if ((failure_count > 0)); then
    echo "Remote Config integration contract matrix failed: $failure_count item(s)."
    exit 1
fi

bash "$platform_root/Scripts/check_special_offer_runtime_contract.sh"

echo "Remote Config integration contract matrix passed; UI expiry rules are owned by BroadUIFlows 1.0.0."
