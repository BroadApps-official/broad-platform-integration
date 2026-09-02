#!/usr/bin/env bash

set -euo pipefail

compatibility_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
compatibility_catalog="$compatibility_root/Compatibility/current.yml"

compatibility_module_version() {
    local module_name="$1"
    /usr/bin/ruby -ryaml -e '
      catalog = YAML.safe_load(File.read(ARGV.fetch(0)))
      puts catalog.fetch("modules").fetch(ARGV.fetch(1))
    ' "$compatibility_catalog" "$module_name"
}

compatibility_platform_set() {
    /usr/bin/ruby -ryaml -e '
      catalog = YAML.safe_load(File.read(ARGV.fetch(0)))
      puts catalog.fetch("platform_set")
    ' "$compatibility_catalog"
}

