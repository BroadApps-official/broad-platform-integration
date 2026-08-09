#!/usr/bin/env bash

set -euo pipefail

platform_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

gate_source_snapshot="$(bash "$platform_root/Scripts/source_snapshot_digest.sh")"
echo "Release source snapshot: $gate_source_snapshot"

echo "[release 1/4] Validate contracts and privacy source"
bash "$platform_root/Scripts/validate.sh"

echo "[release 2/4] Format lint"
bash "$platform_root/Scripts/format.sh" --lint

echo "[release 3/4] SwiftLint"
bash "$platform_root/Scripts/lint.sh"

echo "[release 4/4] Strict-concurrency package and Debug/Release app matrix"
bash "$platform_root/Scripts/build.sh"

post_build_source_snapshot="$(bash "$platform_root/Scripts/source_snapshot_digest.sh")"
if [[ "$post_build_source_snapshot" != "$gate_source_snapshot" ]]; then
    echo "Source changed during the release build; rerun the gate."
    echo "Started: $gate_source_snapshot"
    echo "Ended:   $post_build_source_snapshot"
    exit 1
fi

echo "BroadApps iOS Platform local engineering gate passed."
