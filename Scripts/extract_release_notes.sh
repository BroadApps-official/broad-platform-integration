#!/usr/bin/env bash

set -euo pipefail

export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

platform_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
version="${1:-}"
output="${2:-}"

if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ || -z "$output" ]]; then
    echo "Usage: bash Scripts/extract_release_notes.sh x.y.z output.md"
    exit 1
fi

temporary_output="$(mktemp)"
trap 'rm -f "$temporary_output"' EXIT

# Platform headings may include a date after the exact version.
awk -v version="$version" '
    $1 == "##" && $2 == version { found = 1; print; next }
    found && /^## / { exit }
    found { print; if (NF) has_body = 1 }
    END { if (!found || !has_body) exit 1 }
' "$platform_root/CHANGELOG.md" > "$temporary_output" || {
    echo "CHANGELOG has no non-empty release section for $version."
    exit 1
}

mv "$temporary_output" "$output"
echo "Prepared release notes for $version."
