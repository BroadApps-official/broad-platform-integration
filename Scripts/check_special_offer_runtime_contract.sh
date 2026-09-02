#!/usr/bin/env bash

set -euo pipefail

platform_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$platform_root/Scripts/lib/compatibility.sh"
monetization_version="$(compatibility_module_version BroadMonetization)"

if ! /usr/bin/ruby -ryaml -e '
  catalog = YAML.safe_load(File.read(ARGV.fetch(0)))
  module_record = catalog.fetch("module_verification").fetch("BroadMonetization")
  version = catalog.fetch("modules").fetch("BroadMonetization")
  expected = {
    "version" => version,
    "module_gate" => "passed",
    "github_actions" => "passed",
    "release" => "https://github.com/BroadApps-official/broad-monetization-ios/releases/tag/#{version}"
  }
  exit(expected.all? { |key, value| module_record[key].to_s == value } ? 0 : 1)
' "$platform_root/Compatibility/current.yml"; then
    echo "BroadMonetization $monetization_version runtime evidence is missing."
    exit 1
fi

if ! /usr/bin/ruby "$platform_root/Scripts/check_compatibility_matrix.rb" >/dev/null; then
    echo "Integration does not pin the verified BroadMonetization $monetization_version release."
    exit 1
fi

echo "PASS: Special Offer runtime probe is owned by released BroadMonetization $monetization_version."
echo "PASS: provider payload -> products parsing -> Special Offer; platform cache stays rejected."
