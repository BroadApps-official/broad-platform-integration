#!/usr/bin/env bash

set -euo pipefail

platform_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
expected_swiftformat_version="0.62.1"
local_swiftformat="$platform_root/.build/tooling/swiftformat-0.62.1/swiftformat"

if [[ -n "${SWIFTFORMAT_BINARY:-}" ]]; then
    swiftformat_binary="$SWIFTFORMAT_BINARY"
elif [[ -x "$local_swiftformat" ]]; then
    swiftformat_binary="$local_swiftformat"
elif command -v swiftformat >/dev/null 2>&1; then
    swiftformat_binary="$(command -v swiftformat)"
else
    echo "SwiftFormat is not installed. Run Scripts/install_swiftformat.sh, then try again."
    exit 1
fi

actual_swiftformat_version="$("$swiftformat_binary" --version)"
swiftformat_cache="$platform_root/.build/SwiftFormatCache"

if [[ "$actual_swiftformat_version" != "$expected_swiftformat_version" ]]; then
    echo "SwiftFormat $expected_swiftformat_version is required; found $actual_swiftformat_version at $swiftformat_binary."
    echo "Run Scripts/install_swiftformat.sh or set SWIFTFORMAT_BINARY to the pinned binary."
    exit 1
fi

format_mode="format"

if [[ "${1:-}" == "--lint" ]]; then
    format_mode="lint"
    shift
fi

if [[ "$#" -ne 0 ]]; then
    echo "Usage: Scripts/format.sh [--lint]"
    exit 1
fi

if [[ "$format_mode" == "lint" ]]; then
    "$swiftformat_binary" \
        --config "$platform_root/.swiftformat" \
        --cache "$swiftformat_cache" \
        --lint \
        "$platform_root/Sources" \
        "$platform_root/Examples/BroadAppTemplate/BroadAppTemplate"
else
    "$swiftformat_binary" \
        --config "$platform_root/.swiftformat" \
        --cache "$swiftformat_cache" \
        "$platform_root/Sources" \
        "$platform_root/Examples/BroadAppTemplate/BroadAppTemplate"
fi
