#!/usr/bin/env bash

set -euo pipefail

platform_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
failure_count=0

record_failure() {
    printf '%s\n' "$1"
    failure_count=$((failure_count + 1))
}

require_pattern() {
    local description="$1"
    local file="$2"
    local pattern="$3"

    if ! rg -q --multiline -- "$pattern" "$platform_root/$file"; then
        record_failure "$description: $file -> $pattern"
    fi
}

required_files=(
    "Compatibility/current.yml"
    "Documentation/ADR/0006-federated-public-repositories.md"
    "Documentation/FederatedRepositories.md"
    "Documentation/ModuleReleasePolicy.md"
    "Examples/BroadAppTemplate/BroadAppTemplate.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
    "Scripts/check_compatibility_matrix.rb"
)

package_reference_files=(
    "Package.swift"
    "Package.resolved"
    "Examples/BroadAppTemplate/project.yml"
    "Examples/BroadAppTemplate/BroadAppTemplate.xcodeproj/project.pbxproj"
    "Examples/BroadAppTemplate/BroadAppTemplate.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
)

for relative_path in "${required_files[@]}"; do
    if [[ ! -s "$platform_root/$relative_path" ]]; then
        record_failure "Federation contract is missing: $relative_path"
    fi
done

for relative_path in "${package_reference_files[@]}"; do
    if rg -q -- 'github\.com/BroadApps-official/BroadCore(?:\.git)?'         "$platform_root/$relative_path"; then
        record_failure "Private legacy package URL is forbidden: $relative_path"
    fi
done

if rg -q --glob '*.md' -- 'branch:[[:space:]]*"vers_niiaz"'     "$platform_root/README.md" "$platform_root/Documentation"; then
    record_failure         "Released module documentation must use a compatibility tag, not branch vers_niiaz."
fi

if ! /usr/bin/ruby "$platform_root/Scripts/check_compatibility_matrix.rb"; then
    record_failure "Compatibility catalog and generated package artifacts disagree."
fi

for contract in     'Host app подключает \*\*любой нужный модуль\*\*'     'umbrella package'     'редактируемыми исходниками'     'Tests/.*test targets, XCTest и Swift'
do
    require_pattern         "Federated repository ADR contract is missing"         "Documentation/ADR/0006-federated-public-repositories.md"         "$contract"
done

require_pattern     "Release policy must explain what changed and why"     "Documentation/ModuleReleasePolicy.md"     'объясняет \*\*что\*\* изменилось и \*\*почему\*\*'
require_pattern     "README must explain anonymous public package access"     "README.md"     'без GitHub account, password,[[:space:]]*token или API key'

for module_name in BroadCore BroadExtensions BroadMonetization BroadUIFlows; do
    if rg -q --multiline --         "\\.library\\(name: \"$module_name\"|\\.target\\([[:space:]]*name: \"$module_name\""         "$platform_root/Package.swift"; then
        record_failure "Integration Package.swift still publishes a duplicated local $module_name target."
    fi

    source_path="$platform_root/Sources/$module_name"
    if [[ -d "$source_path" ]] && find "$source_path" -type f -print -quit | rg -q .; then
        record_failure "$module_name production sources still exist in the integration checkout."
    fi
done

for forbidden_claim in     'хост[- ]приложения подключают только BroadPlatform'     'host apps? (must|only) (use|connect|depend on) BroadPlatform'
do
    matches="$(
        rg -n -i --pcre2             "$forbidden_claim"             "$platform_root/README.md"             "$platform_root/README.dev.md"             "$platform_root/Documentation"             "$platform_root/CHANGELOG.md" || true
    )"
    if [[ -n "$matches" ]]; then
        record_failure "Documentation incorrectly requires the umbrella package:\n$matches"
    fi
done

if ((failure_count > 0)); then
    echo "Federation contract validation failed: $failure_count issue(s)."
    exit 1
fi

echo "Federation contracts are valid."
