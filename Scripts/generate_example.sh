#!/usr/bin/env bash

set -euo pipefail

platform_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
example_root="$platform_root/Examples/BroadAppTemplate"
expected_xcodegen_version="2.45.4"
local_xcodegen="$platform_root/.build/tooling/xcodegen-$expected_xcodegen_version/xcodegen/bin/xcodegen"

if [[ -n "${XCODEGEN_BINARY:-}" ]]; then
    xcodegen_binary="$XCODEGEN_BINARY"
elif [[ -x "$local_xcodegen" ]]; then
    xcodegen_binary="$local_xcodegen"
elif command -v xcodegen >/dev/null 2>&1; then
    xcodegen_binary="$(command -v xcodegen)"
else
    echo "XcodeGen $expected_xcodegen_version is required but is not installed."
    echo "Run Scripts/install_build_tools.sh, then try again."
    exit 1
fi

actual_xcodegen_version="$("$xcodegen_binary" --version | awk '{print $NF}' | tr -d '[:space:]')"
if [[ "$actual_xcodegen_version" != "$expected_xcodegen_version" ]]; then
    echo "XcodeGen version mismatch: expected $expected_xcodegen_version, got $actual_xcodegen_version."
    exit 1
fi

"$xcodegen_binary" generate --spec "$example_root/project.yml"
