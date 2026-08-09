#!/usr/bin/env bash

set -euo pipefail

platform_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
example_root="$platform_root/Examples/BroadAppTemplate"
expected_xcodegen_version="2.45.4"

if ! command -v xcodegen >/dev/null 2>&1; then
    echo "XcodeGen $expected_xcodegen_version is required but is not installed."
    exit 1
fi

actual_xcodegen_version="$(xcodegen --version | awk '{print $NF}' | tr -d '[:space:]')"
if [[ "$actual_xcodegen_version" != "$expected_xcodegen_version" ]]; then
    echo "XcodeGen version mismatch: expected $expected_xcodegen_version, got $actual_xcodegen_version."
    exit 1
fi

xcodegen generate --spec "$example_root/project.yml"
