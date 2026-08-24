#!/usr/bin/env bash

set -euo pipefail

platform_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
swiftlint_version="0.62.2"
swiftlint_checksum="79625bece2716395d955d34a5993e6c948ef57d0256abe5538aaab82f2ad6b68"
swiftlint_directory="$platform_root/.build/tooling/swiftlint-$swiftlint_version"
swiftlint_binary="$swiftlint_directory/swiftlint"
xcodegen_version="2.45.4"
xcodegen_checksum="090ec29491aad50aec10631bf6e62253fed733c50f3aab0f5ffc86bc170bdbef"
xcodegen_directory="$platform_root/.build/tooling/xcodegen-$xcodegen_version"
xcodegen_binary="$xcodegen_directory/xcodegen/bin/xcodegen"

install_swiftlint() {
    local temporary_directory archive actual_checksum
    temporary_directory="$(mktemp -d)"
    archive="$temporary_directory/portable_swiftlint.zip"
    curl --fail --location --silent --show-error \
        "https://github.com/realm/SwiftLint/releases/download/$swiftlint_version/portable_swiftlint.zip" \
        --output "$archive"
    actual_checksum="$(shasum -a 256 "$archive" | awk '{print $1}')"
    if [[ "$actual_checksum" != "$swiftlint_checksum" ]]; then
        echo "SwiftLint checksum mismatch. Expected $swiftlint_checksum, received $actual_checksum."
        rm -rf "$temporary_directory"
        exit 1
    fi
    mkdir -p "$swiftlint_directory"
    unzip -oq "$archive" swiftlint -d "$swiftlint_directory"
    chmod +x "$swiftlint_binary"
    rm -rf "$temporary_directory"
}

install_xcodegen() {
    local temporary_directory archive actual_checksum
    temporary_directory="$(mktemp -d)"
    archive="$temporary_directory/xcodegen.zip"
    curl --fail --location --silent --show-error \
        "https://github.com/yonaskolb/XcodeGen/releases/download/$xcodegen_version/xcodegen.zip" \
        --output "$archive"
    actual_checksum="$(shasum -a 256 "$archive" | awk '{print $1}')"
    if [[ "$actual_checksum" != "$xcodegen_checksum" ]]; then
        echo "XcodeGen checksum mismatch. Expected $xcodegen_checksum, received $actual_checksum."
        rm -rf "$temporary_directory"
        exit 1
    fi
    mkdir -p "$xcodegen_directory"
    unzip -oq "$archive" -d "$xcodegen_directory"
    chmod +x "$xcodegen_binary"
    rm -rf "$temporary_directory"
}

if [[ ! -x "$swiftlint_binary" ]] || \
    [[ "$("$swiftlint_binary" version 2>/dev/null | tr -d '[:space:]')" != "$swiftlint_version" ]]; then
    install_swiftlint
fi

if [[ ! -x "$xcodegen_binary" ]] || \
    [[ "$("$xcodegen_binary" --version 2>/dev/null | awk '{print $2}')" != "$xcodegen_version" ]]; then
    install_xcodegen
fi

if [[ "$("$swiftlint_binary" version | tr -d '[:space:]')" != "$swiftlint_version" ]]; then
    echo "SwiftLint $swiftlint_version was downloaded but could not be verified."
    exit 1
fi
if [[ "$("$xcodegen_binary" --version | awk '{print $2}')" != "$xcodegen_version" ]]; then
    echo "XcodeGen $xcodegen_version was downloaded but could not be verified."
    exit 1
fi

echo "SwiftLint $swiftlint_version and XcodeGen $xcodegen_version are installed locally."
