#!/usr/bin/env bash

set -euo pipefail

platform_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
expected_swiftlint_version="0.62.2"

if ! command -v swiftlint >/dev/null 2>&1; then
    echo "SwiftLint $expected_swiftlint_version is required but is not installed."
    exit 1
fi

actual_swiftlint_version="$(swiftlint version | tr -d '[:space:]')"
if [[ "$actual_swiftlint_version" != "$expected_swiftlint_version" ]]; then
    echo "SwiftLint version mismatch: expected $expected_swiftlint_version, got $actual_swiftlint_version."
    exit 1
fi

swiftlint lint --strict --config "$platform_root/.swiftlint.yml"
"$platform_root/Scripts/check_architecture.sh"
