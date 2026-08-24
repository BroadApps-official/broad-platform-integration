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

    if ! rg -q -- "$pattern" "$platform_root/$file"; then
        record_failure "$description: $file -> $pattern"
    fi
}

required_files=(
    "Compatibility/current.yml"
    "Documentation/ADR/0006-federated-public-repositories.md"
    "Documentation/FederatedRepositories.md"
    "Documentation/ModuleReleasePolicy.md"
)

for relative_path in "${required_files[@]}"; do
    if [[ ! -s "$platform_root/$relative_path" ]]; then
        record_failure "Federation contract is missing: $relative_path"
    fi
done

if ((failure_count == 0)); then
    for repository in \
        broad-core-ios \
        broad-extensions-ios \
        broad-monetization-ios \
        broad-ui-flows-ios
    do
        require_pattern \
            "Module repository is absent from the compatibility catalog" \
            "Compatibility/current.yml" \
            "https://github.com/BroadApps-official/$repository"
    done

    for contract in \
        '^schema: 1$' \
        '^platform_set:' \
        '^ios: "17\.0"$' \
        '^swift_tools: "6\.0"$' \
        '^modules:$' \
        '^verification:$' \
        '^  status: (pending|passed)$'
    do
        require_pattern \
            "Compatibility catalog field is missing" \
            "Compatibility/current.yml" \
            "$contract"
    done

    require_pattern \
        "ADR must allow direct module selection by a host app" \
        "Documentation/ADR/0006-federated-public-repositories.md" \
        'Host app подключает \*\*любой нужный модуль\*\*'
    require_pattern \
        "ADR must reject a mandatory umbrella package" \
        "Documentation/ADR/0006-federated-public-repositories.md" \
        'umbrella package'
    require_pattern \
        "ADR must keep repository documentation editable" \
        "Documentation/ADR/0006-federated-public-repositories.md" \
        'редактируемыми исходниками'
    require_pattern \
        "ADR must forbid test targets" \
        "Documentation/ADR/0006-federated-public-repositories.md" \
        'Tests/.*test targets, XCTest и Swift'
    require_pattern \
        "Release policy must explain what changed and why" \
        "Documentation/ModuleReleasePolicy.md" \
        'объясняет \*\*что\*\* изменилось и \*\*почему\*\*'
fi

for forbidden_claim in \
    'хост[- ]приложения подключают только BroadPlatform' \
    'host apps? (must|only) (use|connect|depend on) BroadPlatform'
do
    matches="$(
        rg -n -i --pcre2 \
            "$forbidden_claim" \
            "$platform_root/README.md" \
            "$platform_root/README.dev.md" \
            "$platform_root/Documentation" \
            "$platform_root/CHANGELOG.md" || true
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
