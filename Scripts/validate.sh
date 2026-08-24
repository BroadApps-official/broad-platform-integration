#!/usr/bin/env bash

set -euo pipefail

platform_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
failure_count=0

record_failure() {
    local title="$1"
    local details="$2"

    echo "$title"
    if [[ -n "$details" ]]; then
        echo "$details"
    fi
    failure_count=$((failure_count + 1))
}

capture_rg() {
    local pattern="$1"
    shift

    local output=""
    local status=0
    output="$(rg -n --pcre2 "$pattern" "$@")" || status=$?

    case "$status" in
        0)
            echo "$output"
            ;;
        1)
            ;;
        *)
            echo "Validation scan could not run."
            exit "$status"
            ;;
    esac
}

if ! command -v rg >/dev/null 2>&1; then
    echo "ripgrep is required for local validation."
    exit 1
fi

echo "[1/9] Package structure"

required_check_files=(
    "$platform_root/AGENTS.md"
    "$platform_root/AgentChecks/AUTOMATION_PROMPT.md"
    "$platform_root/AgentChecks/AutomationReports/README.md"
    "$platform_root/AgentChecks/STATUS.md"
    "$platform_root/Scripts/lib/console.sh"
)
for required_file in "${required_check_files[@]}"; do
    if [[ ! -s "$required_file" ]]; then
        record_failure "Required checking-agent definition is missing:" "$required_file"
    fi
done

required_automation_files=(
    "$platform_root/Scripts/agent_gate.sh"
    "$platform_root/Scripts/agent_review_and_fix.sh"
    "$platform_root/Scripts/check_adapty_experiment_contracts.sh"
    "$platform_root/Scripts/check_federation_contracts.sh"
    "$platform_root/Scripts/check_onboarding_contract.sh"
    "$platform_root/Scripts/check_remote_feature_contracts.sh"
    "$platform_root/Scripts/check_special_offer_runtime_contract.sh"
    "$platform_root/Scripts/check_live_adapty_builds.sh"
    "$platform_root/Scripts/stream_example_logs.sh"
)
for required_file in "${required_automation_files[@]}"; do
    if [[ ! -x "$required_file" ]]; then
        record_failure "Required automation script is missing or not executable:" "$required_file"
    elif ! bash -n "$required_file"; then
        record_failure "Required automation script has invalid Bash syntax:" "$required_file"
    fi
done

test_target_matches="$(capture_rg '\.testTarget[[:space:]]*\(' "$platform_root/Package.swift")"
if [[ -n "$test_target_matches" ]]; then
    record_failure "Swift Package test targets are forbidden:" "$test_target_matches"
fi

xcode_test_matches="$(
    capture_rg \
        'com\.apple\.product-type\.bundle\.(unit-test|ui-testing)' \
        "$platform_root/Examples" \
        --glob '*.pbxproj'
)"
if [[ -n "$xcode_test_matches" ]]; then
    record_failure "Xcode test targets are forbidden:" "$xcode_test_matches"
fi

if ! rg -q '^[[:space:]]*TARGETED_DEVICE_FAMILY:[[:space:]]*"1"[[:space:]]*$' \
    "$platform_root/Examples/BroadAppTemplate/project.yml"; then
    record_failure \
        "Example must remain iPhone-only:" \
        "Examples/BroadAppTemplate/project.yml must set TARGETED_DEVICE_FAMILY to 1."
fi

unsupported_platform_matches="$(
    capture_rg \
        '(TARGETED_DEVICE_FAMILY:[[:space:]]*"[^"]*(2|6|7)|UISupportedInterfaceOrientations[_~]iPad|\.macOS[[:space:]]*\(|\.visionOS[[:space:]]*\(|Mac Catalyst)' \
        "$platform_root/Package.swift" \
        "$platform_root/Examples/BroadAppTemplate/project.yml" \
        "$platform_root/Examples/BroadAppTemplate/Configuration/LiveAdaptyInfo.plist"
)"
if [[ -n "$unsupported_platform_matches" ]]; then
    record_failure "iPad/Mac/visionOS configuration is forbidden:" "$unsupported_platform_matches"
fi

test_import_matches="$(
    capture_rg \
        '^[[:space:]]*import[[:space:]]+(XCTest|Testing)[[:space:]]*$' \
        "$platform_root/Sources" \
        "$platform_root/Examples" \
        --glob '*.swift'
)"
if [[ -n "$test_import_matches" ]]; then
    record_failure "Test frameworks are forbidden in platform sources:" "$test_import_matches"
fi

tests_directories="$(
    find "$platform_root" \
        \( -path "$platform_root/.build" -o \
           -path "$platform_root/.swiftpm" -o \
           -path "$platform_root/.git" \) \
        -prune -o \
        -type d -name Tests -print
)"
if [[ -n "$tests_directories" ]]; then
    record_failure "Tests directories are forbidden:" "$tests_directories"
fi

echo "[2/9] Local references"

reference_directories="$(
    find "$platform_root" \
        \( -path "$platform_root/.build" -o \
           -path "$platform_root/.swiftpm" -o \
           -path "$platform_root/.git" \) \
        -prune -o \
        -type d \
        \( -iname 5109Codex -o -iname Claude232 -o -iname 5013 -o -iname 'Шаблон' \) \
        -print
)"
if [[ -n "$reference_directories" ]]; then
    record_failure "Reference repositories must not be embedded in the platform:" "$reference_directories"
fi

nested_repositories="$(
    find "$platform_root" \
        \( -path "$platform_root/.build" -o \
           -path "$platform_root/.swiftpm" -o \
           -path "$platform_root/.git" \) \
        -prune -o \
        -type d -name .git -print
)"
if [[ -n "$nested_repositories" ]]; then
    record_failure "Nested repositories must not be embedded in the platform:" "$nested_repositories"
fi

absolute_reference_matches="$(
    capture_rg \
        '(/Users/|/Volumes/|file://)' \
        "$platform_root/Package.swift" \
        "$platform_root/Package.resolved" \
        "$platform_root/README.md" \
        "$platform_root/AgentChecks" \
        "$platform_root/Documentation" \
        "$platform_root/Sources" \
        "$platform_root/Examples" \
        --glob '*.swift' \
        --glob '*.md' \
        --glob '*.yml' \
        --glob '*.yaml' \
        --glob '*.json' \
        --glob '*.plist' \
        --glob '*.pbxproj' \
        --glob '*.xcconfig' \
        --glob '*.xcworkspacedata' \
        --glob 'Package.swift' \
        --glob 'Package.resolved' \
        --glob '!AutomationReports/**'
)"
if [[ -n "$absolute_reference_matches" ]]; then
    record_failure "Local machine or reference-repository paths are forbidden:" "$absolute_reference_matches"
fi

local_package_matches="$(
    capture_rg \
        '\.package[[:space:]]*\([[:space:]]*path[[:space:]]*:' \
        "$platform_root/Package.swift" \
        --multiline
)"
if [[ -n "$local_package_matches" ]]; then
    record_failure "Root Package.swift must not depend on a local package path:" "$local_package_matches"
fi

echo "[3/9] Federation contracts"
if ! bash "$platform_root/Scripts/check_federation_contracts.sh"; then
    failure_count=$((failure_count + 1))
fi

echo "[4/9] Architecture and product guardrails"
if ! bash "$platform_root/Scripts/check_architecture.sh"; then
    failure_count=$((failure_count + 1))
fi

echo "[5/9] Onboarding contracts"
if ! bash "$platform_root/Scripts/check_onboarding_contract.sh"; then
    failure_count=$((failure_count + 1))
fi

echo "[6/9] Remote Config feature-gate contracts"
if ! bash "$platform_root/Scripts/check_remote_feature_contracts.sh"; then
    failure_count=$((failure_count + 1))
fi

echo "[7/9] Adapty experiment contracts"
if ! bash "$platform_root/Scripts/check_adapty_experiment_contracts.sh"; then
    failure_count=$((failure_count + 1))
fi

echo "[8/9] Privacy manifest"
if ! bash "$platform_root/Scripts/check_privacy_manifest.sh"; then
    failure_count=$((failure_count + 1))
fi

echo "[9/9] Documentation and README assets"
if ! bash "$platform_root/Scripts/check_documentation.sh"; then
    failure_count=$((failure_count + 1))
fi

if ((failure_count > 0)); then
    echo "Local validation failed: $failure_count check group(s)."
    exit 1
fi

echo "Local validation passed."
