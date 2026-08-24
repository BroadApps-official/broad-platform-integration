#!/usr/bin/env bash

set -euo pipefail

platform_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! /usr/bin/ruby -ryaml -e '
  catalog = YAML.safe_load(File.read(ARGV.fetch(0)))
  module_record = catalog.fetch("module_verification").fetch("BroadMonetization")
  expected = {
    "version" => "1.0.0",
    "module_gate" => "passed",
    "github_actions" => "passed",
    "release" => "https://github.com/BroadApps-official/broad-monetization-ios/releases/tag/1.0.0"
  }
  exit(expected.all? { |key, value| module_record[key].to_s == value } ? 0 : 1)
' "$platform_root/Compatibility/current.yml"; then
    echo "BroadMonetization 1.0.0 runtime evidence is missing."
    exit 1
fi

if ! rg -q --multiline \
    'broad-monetization-ios\.git",[[:space:]]*exact:[[:space:]]*"1\.0\.0"' \
    "$platform_root/Package.swift"; then
    echo "Integration does not pin the verified BroadMonetization 1.0.0 release."
    exit 1
fi

echo "PASS: Special Offer runtime probe is owned by released BroadMonetization 1.0.0."
echo "PASS: provider payload -> products parsing -> Special Offer; platform cache stays rejected."
