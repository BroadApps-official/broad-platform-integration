#!/usr/bin/env bash

set -euo pipefail

platform_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
violation_count=0

fixed_length_pattern='(pages\.count[[:space:]]*(==|!=|<=|>=|<|>)[[:space:]]*3\b|currentIndex[[:space:]]*(==|!=|<=|>=|<|>)[[:space:]]*2\b|pages[[:space:]]*\[[[:space:]]*2[[:space:]]*\]|0[[:space:]]*\.\.\.?[[:space:]]*2\b|0[[:space:]]*\.\.<[[:space:]]*3\b|ForEach[[:space:]]*\([[:space:]]*0[[:space:]]*\.\.<[[:space:]]*3\b)'
fixed_documentation_pattern='(?i)(onboarding[^\n]{0,100}(всегда[[:space:]]+состоит|состоит[[:space:]]+по[[:space:]]+умолчанию|ограничен[^\n]{0,30})[^\n]{0,60}(3|три|тр[её]х)[^\n]{0,40}(слайд|страниц|экран)|(обязательн(ые|ых)?)[[:space:]]+(3|три)[[:space:]]+(слайда|страницы|экрана)|лимит[[:space:]]+платформы[^\n]{0,30}(3|три))'

record_violation() {
    local title="$1"
    local details="$2"

    echo "$title"
    if [[ -n "$details" ]]; then
        echo "$details"
    fi
    violation_count=$((violation_count + 1))
}

scan_forbidden() {
    local title="$1"
    local pattern="$2"
    shift 2

    local output=""
    local status=0
    output="$(rg -n --pcre2 "$pattern" "$@")" || status=$?

    case "$status" in
        0)
            record_violation "$title" "$output"
            ;;
        1)
            ;;
        *)
            echo "Onboarding contract scan could not run: $title"
            exit "$status"
            ;;
    esac
}

require_pattern() {
    local title="$1"
    local file="$2"
    local pattern="$3"
    local status=0

    rg -q --pcre2 --multiline "$pattern" "$file" || status=$?
    case "$status" in
        0)
            ;;
        1)
            record_violation "$title" "${file#$platform_root/}"
            ;;
        *)
            echo "Onboarding contract requirement could not run: $title"
            exit "$status"
            ;;
    esac
}

run_self_test() {
    local bad_source='if pages.count == 3 { currentIndex = 2 }'
    local bad_documentation='Onboarding всегда состоит из трёх слайдов.'

    if ! printf '%s\n' "$bad_source" | rg -q --pcre2 "$fixed_length_pattern"; then
        echo "SELF-TEST FAILED: fixed three-page source was not rejected."
        exit 1
    fi

    if ! printf '%s\n' "$bad_documentation" | rg -q --pcre2 "$fixed_documentation_pattern"; then
        echo "SELF-TEST FAILED: fixed three-page documentation was not rejected."
        exit 1
    fi

    echo "Onboarding contract self-test passed: synthetic three-page regressions are rejected."
}

if [[ "${1:-}" == "--self-test" ]]; then
    run_self_test
    exit 0
fi

if ! command -v rg >/dev/null 2>&1; then
    echo "ripgrep is required for onboarding contract validation."
    exit 1
fi

example_onboarding_root="$platform_root/Examples/BroadAppTemplate/BroadAppTemplate/Presentation/Onboarding"

scan_forbidden \
    "The app-owned onboarding renderer must not contain fixed page indexes:" \
    "$fixed_length_pattern" \
    "$example_onboarding_root" \
    --glob '*.swift'

scan_forbidden \
    "Documentation must not claim that onboarding is always limited to three pages:" \
    "$fixed_documentation_pattern" \
    "$platform_root/README.md" \
    "$platform_root/README.dev.md" \
    "$platform_root/AGENTS.md" \
    "$platform_root/Documentation" \
    "$platform_root/Examples/BroadAppTemplate/README.md" \
    "$platform_root/AgentChecks/AUTOMATION_PROMPT.md" \
    --glob '*.md'

scan_forbidden \
    "Host-owned onboarding must not contain Rate Us or native review requests:" \
    '(?i)\b(rate[[:space:]_-]*us|request[[:space:]_-]*review|SKStoreReviewController|AppStore\.requestReview|оценить|отзыв)\b' \
    "$example_onboarding_root" \
    --glob '*.swift'

loader_paths=()
for loader_path in \
    "$platform_root/Examples/BroadAppTemplate/BroadAppTemplate/Presentation/Root"; do
    if [[ -d "$loader_path" ]]; then
        loader_paths+=("$loader_path")
    fi
done

if ((${#loader_paths[@]} > 0)); then
    scan_forbidden \
        "Loader and bootstrap code must not request ATT:" \
        '(AppTrackingTransparency|ATTrackingManager|TrackingAuthorization|requestTrackingAuthorization|firstSlideDidAppear)' \
        "${loader_paths[@]}" \
        --glob '*.swift'
fi

require_pattern \
    "Integration must pin the released BroadUIFlows onboarding contract:" \
    "$platform_root/Package.swift" \
    'broad-ui-flows-ios\.git",[[:space:]]*exact:[[:space:]]*"1\.0\.0"'

require_pattern \
    "BroadUIFlows release must have standalone module and CI evidence:" \
    "$platform_root/Compatibility/current.yml" \
    '(?s)BroadUIFlows:[[:space:]]*\n[[:space:]]+version:[[:space:]]*"1\.0\.0".*module_gate:[[:space:]]*passed.*github_actions:[[:space:]]*passed'

require_pattern \
    "BroadAppTemplate must expose one, two, four, long, custom, disabled and invalid onboarding fixtures:" \
    "$platform_root/Examples/BroadAppTemplate/BroadAppTemplate/Infrastructure/Configuration/ExampleOnboardingScenario.swift" \
    '(?s)case[[:space:]]+onePage.*case[[:space:]]+twoPages.*case[[:space:]]+fourPages.*case[[:space:]]+long.*case[[:space:]]+customUI.*case[[:space:]]+disabled.*case[[:space:]]+invalid'

require_pattern \
    "The custom example must use BroadOnboardingFlowHost instead of duplicating lifecycle logic:" \
    "$platform_root/Examples/BroadAppTemplate/BroadAppTemplate/Presentation/Onboarding/ExampleCustomOnboardingView.swift" \
    'BroadOnboardingFlowHost\('

require_pattern \
    "AGENTS.md must forbid a silent three-page default:" \
    "$platform_root/AGENTS.md" \
    'Три страницы `BroadAppTemplate` являются примером, а не[[:space:]]+значением по умолчанию'

require_pattern \
    "README must visibly explain that three pages are only an example:" \
    "$platform_root/README.md" \
    'Три слайда в `BroadAppTemplate` — только демонстрационный пример'

if ((violation_count > 0)); then
    echo "Onboarding contract validation failed: $violation_count violation(s)."
    exit 1
fi

echo "Onboarding contract validation passed; production flow rules are owned by BroadUIFlows 1.0.0."
