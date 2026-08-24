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
            echo "Adapty integration check could not run: $description"
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
            echo "Adapty integration check could not run: $description"
            exit "$status"
            ;;
    esac
}

echo "Adapty integration contract matrix"

require_pattern \
    "BroadUIFlows consumes the released BroadMonetization product" \
    "$platform_root/Package.swift" \
    '\.product\(name:[[:space:]]*"BroadMonetization",[[:space:]]*package:[[:space:]]*"broad-monetization-ios"\)'

require_pattern \
    "Host analytics still fan out only after deduplication" \
    "$platform_root/Examples/BroadAppTemplate/BroadAppTemplate/Infrastructure/Analytics/ExampleMonetizationAnalyticsAssembly.swift" \
    'destination:[[:space:]]*deduplicated'

require_pattern \
    "Host analytics keep their composite destination" \
    "$platform_root/Examples/BroadAppTemplate/BroadAppTemplate/Infrastructure/Analytics/ExampleMonetizationAnalyticsAssembly.swift" \
    'CompositeMonetizationAnalytics'

forbid_pattern \
    "Host and UI contain no duplicate experiment assignment" \
    '(?i)\b(ExperimentAssignment|CohortAssignment|SegmentAssignment|ExperimentRandomizer|CohortRandomizer|ClientSideRandomizer)\b' \
    "$platform_root/Sources/BroadUIFlows" \
    "$platform_root/Examples/BroadAppTemplate/BroadAppTemplate" \
    --glob '*.swift'

if ((failure_count > 0)); then
    echo "Adapty integration contract matrix failed: $failure_count item(s)."
    exit 1
fi

echo "Adapty integration contracts are delegated to BroadMonetization 1.0.0 and passed."
