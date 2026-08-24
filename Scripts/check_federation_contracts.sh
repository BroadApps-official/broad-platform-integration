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

    for extensions_contract in \
        '^  BroadExtensions: "1\.0\.0"$' \
        '^    version: "1\.0\.0"$' \
        '^    module_gate: passed$' \
        '^    github_actions: passed$' \
        '^    integration_gate: passed$' \
        'broad-extensions-ios/releases/tag/1\.0\.0'
    do
        require_pattern \
            "Released BroadExtensions evidence is missing" \
            "Compatibility/current.yml" \
            "$extensions_contract"
    done

    require_pattern \
        "Integration Package.swift must pin BroadExtensions 1.0.0" \
        "Package.swift" \
        'broad-extensions-ios\.git",[[:space:]]*exact:[[:space:]]*"1\.0\.0"'
    require_pattern \
        "Integration Package.swift must pin BroadCore 1.0.0" \
        "Package.swift" \
        'broad-core-ios\.git",[[:space:]]*exact:[[:space:]]*"1\.0\.0"'
    require_pattern \
        "Integration Package.swift must pin BroadMonetization 1.0.0" \
        "Package.swift" \
        'broad-monetization-ios\.git",[[:space:]]*exact:[[:space:]]*"1\.0\.0"'
    require_pattern \
        "Integration Package.swift must pin BroadUIFlows 1.0.0" \
        "Package.swift" \
        'broad-ui-flows-ios\.git",[[:space:]]*exact:[[:space:]]*"1\.0\.0"'

    if ! /usr/bin/ruby -ryaml -e '
      catalog = YAML.safe_load(File.read(ARGV.fetch(0)))
      core = catalog.fetch("module_verification").fetch("BroadCore")
      expected = {
        "version" => "1.0.0",
        "module_gate" => "passed",
        "github_actions" => "passed",
        "release" => "https://github.com/BroadApps-official/broad-core-ios/releases/tag/1.0.0",
        "integration_gate" => "passed",
        "checked_at" => "2026-08-24"
      }
      exit(expected.all? { |key, value| core[key].to_s == value } ? 0 : 1)
    ' "$platform_root/Compatibility/current.yml"; then
        record_failure "Released BroadCore evidence is missing or inconsistent in Compatibility/current.yml."
    fi

    if ! /usr/bin/ruby -ryaml -e '
      catalog = YAML.safe_load(File.read(ARGV.fetch(0)))
      monetization = catalog.fetch("module_verification").fetch("BroadMonetization")
      expected = {
        "version" => "1.0.0",
        "module_gate" => "passed",
        "github_actions" => "passed",
        "release" => "https://github.com/BroadApps-official/broad-monetization-ios/releases/tag/1.0.0",
        "integration_gate" => "passed",
        "checked_at" => "2026-08-24"
      }
      exit(expected.all? { |key, value| monetization[key].to_s == value } ? 0 : 1)
    ' "$platform_root/Compatibility/current.yml"; then
        record_failure "Released BroadMonetization evidence is missing or inconsistent in Compatibility/current.yml."
    fi

    if ! /usr/bin/ruby -ryaml -e '
      catalog = YAML.safe_load(File.read(ARGV.fetch(0)))
      ui_flows = catalog.fetch("module_verification").fetch("BroadUIFlows")
      expected = {
        "version" => "1.0.0",
        "module_gate" => "passed",
        "github_actions" => "passed",
        "release" => "https://github.com/BroadApps-official/broad-ui-flows-ios/releases/tag/1.0.0",
        "integration_gate" => "passed",
        "checked_at" => "2026-08-25"
      }
      exit(expected.all? { |key, value| ui_flows[key].to_s == value } ? 0 : 1)
    ' "$platform_root/Compatibility/current.yml"; then
        record_failure "Released BroadUIFlows evidence is missing or inconsistent in Compatibility/current.yml."
    fi

    for example_contract in \
        'url: https://github\.com/BroadApps-official/broad-extensions-ios\.git' \
        'exactVersion: 1\.0\.0' \
        'package: BroadExtensions' \
        'product: BroadExtensions'
    do
        require_pattern \
            "Integration example does not compile BroadExtensions 1.0.0" \
            "Examples/BroadAppTemplate/project.yml" \
            "$example_contract"
    done

    for core_example_contract in \
        'url: https://github\.com/BroadApps-official/broad-core-ios\.git' \
        'exactVersion: 1\.0\.0' \
        'package: BroadCore' \
        'product: BroadCore'
    do
        require_pattern \
            "Integration example does not compile BroadCore 1.0.0" \
            "Examples/BroadAppTemplate/project.yml" \
            "$core_example_contract"
    done

    for monetization_example_contract in \
        'url: https://github\.com/BroadApps-official/broad-monetization-ios\.git' \
        'exactVersion: 1\.0\.0' \
        'package: BroadMonetization' \
        'product: BroadMonetization'
    do
        require_pattern \
            "Integration example does not compile BroadMonetization 1.0.0" \
            "Examples/BroadAppTemplate/project.yml" \
            "$monetization_example_contract"
    done

    for ui_flows_example_contract in \
        'url: https://github\.com/BroadApps-official/broad-ui-flows-ios\.git' \
        'exactVersion: 1\.0\.0' \
        'package: BroadUIFlows' \
        'product: BroadUIFlows'
    do
        require_pattern \
            "Integration example does not compile BroadUIFlows 1.0.0" \
            "Examples/BroadAppTemplate/project.yml" \
            "$ui_flows_example_contract"
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

if rg -q -- '\.library\(name: "BroadExtensions"|\.target\([[:space:]]*name: "BroadExtensions"' \
    "$platform_root/Package.swift"; then
    record_failure "Integration Package.swift still publishes a duplicated local BroadExtensions target."
fi

if [[ -d "$platform_root/Sources/BroadExtensions" ]] && \
    find "$platform_root/Sources/BroadExtensions" -type f -print -quit | rg -q .; then
    record_failure "BroadExtensions production sources still exist in the integration checkout."
fi

if rg -q --multiline -- '\.library\(name: "BroadCore"|\.target\([[:space:]]*name: "BroadCore"' \
    "$platform_root/Package.swift"; then
    record_failure "Integration Package.swift still publishes a duplicated local BroadCore target."
fi

if [[ -d "$platform_root/Sources/BroadCore" ]] && \
    find "$platform_root/Sources/BroadCore" -type f -print -quit | rg -q .; then
    record_failure "BroadCore production sources still exist in the integration checkout."
fi

if rg -q --multiline -- '\.library\(name: "BroadMonetization"|\.target\([[:space:]]*name: "BroadMonetization"' \
    "$platform_root/Package.swift"; then
    record_failure "Integration Package.swift still publishes a duplicated local BroadMonetization target."
fi

if [[ -d "$platform_root/Sources/BroadMonetization" ]] && \
    find "$platform_root/Sources/BroadMonetization" -type f -print -quit | rg -q .; then
    record_failure "BroadMonetization production sources still exist in the integration checkout."
fi

if rg -q --multiline -- '\.library\(name: "BroadUIFlows"|\.target\([[:space:]]*name: "BroadUIFlows"' \
    "$platform_root/Package.swift"; then
    record_failure "Integration Package.swift still publishes a duplicated local BroadUIFlows target."
fi

if [[ -d "$platform_root/Sources/BroadUIFlows" ]] && \
    find "$platform_root/Sources/BroadUIFlows" -type f -print -quit | rg -q .; then
    record_failure "BroadUIFlows production sources still exist in the integration checkout."
fi

if ! /usr/bin/ruby -rjson -e '
  resolved = JSON.parse(File.read(ARGV.fetch(0)))
  pin = resolved.fetch("pins").find { |item| item["identity"] == "broad-extensions-ios" }
  exit(pin&.dig("state", "version") == "1.0.0" ? 0 : 1)
' "$platform_root/Package.resolved"; then
    record_failure "Package.resolved does not pin BroadExtensions 1.0.0."
fi

if ! /usr/bin/ruby -rjson -e '
  resolved = JSON.parse(File.read(ARGV.fetch(0)))
  pin = resolved.fetch("pins").find { |item| item["identity"] == "broad-core-ios" }
  exit(pin&.dig("state", "version") == "1.0.0" ? 0 : 1)
' "$platform_root/Package.resolved"; then
    record_failure "Package.resolved does not pin BroadCore 1.0.0."
fi

if ! /usr/bin/ruby -rjson -e '
  resolved = JSON.parse(File.read(ARGV.fetch(0)))
  pin = resolved.fetch("pins").find { |item| item["identity"] == "broad-monetization-ios" }
  exit(pin&.dig("state", "version") == "1.0.0" ? 0 : 1)
' "$platform_root/Package.resolved"; then
    record_failure "Package.resolved does not pin BroadMonetization 1.0.0."
fi

if ! /usr/bin/ruby -rjson -e '
  resolved = JSON.parse(File.read(ARGV.fetch(0)))
  pin = resolved.fetch("pins").find { |item| item["identity"] == "broad-ui-flows-ios" }
  exit(pin&.dig("state", "version") == "1.0.0" ? 0 : 1)
' "$platform_root/Package.resolved"; then
    record_failure "Package.resolved does not pin BroadUIFlows 1.0.0."
fi

if ! /usr/bin/ruby -rjson -e '
  resolved = JSON.parse(File.read(ARGV.fetch(0)))
  versions = resolved.fetch("pins").to_h { |item| [item.fetch("identity"), item.dig("state", "version")] }
  expected = {
    "broad-core-ios" => "1.0.0",
    "broad-extensions-ios" => "1.0.0",
    "broad-monetization-ios" => "1.0.0",
    "broad-ui-flows-ios" => "1.0.0"
  }
  exit(expected.all? { |identity, version| versions[identity] == version } ? 0 : 1)
' "$platform_root/Examples/BroadAppTemplate/BroadAppTemplate.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"; then
    record_failure "BroadAppTemplate Xcode lockfile does not pin the four module releases at 1.0.0."
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
