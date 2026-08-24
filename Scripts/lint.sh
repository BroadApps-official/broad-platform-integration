#!/usr/bin/env bash

set -euo pipefail

platform_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
expected_swiftlint_version="0.62.2"
local_swiftlint="$platform_root/.build/tooling/swiftlint-$expected_swiftlint_version/swiftlint"

if [[ -n "${SWIFTLINT_BINARY:-}" ]]; then
    swiftlint_binary="$SWIFTLINT_BINARY"
elif [[ -x "$local_swiftlint" ]]; then
    swiftlint_binary="$local_swiftlint"
elif command -v swiftlint >/dev/null 2>&1; then
    swiftlint_binary="$(command -v swiftlint)"
else
    echo "SwiftLint $expected_swiftlint_version is required but is not installed."
    echo "Run Scripts/install_build_tools.sh, then try again."
    exit 1
fi

actual_swiftlint_version="$("$swiftlint_binary" version | tr -d '[:space:]')"
if [[ "$actual_swiftlint_version" != "$expected_swiftlint_version" ]]; then
    echo "SwiftLint version mismatch: expected $expected_swiftlint_version, got $actual_swiftlint_version."
    exit 1
fi

"$swiftlint_binary" lint --strict --config "$platform_root/.swiftlint.yml"
"$platform_root/Scripts/check_architecture.sh"
