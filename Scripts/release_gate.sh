#!/usr/bin/env bash

set -euo pipefail

platform_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
gate_mode="${BROADAPPS_GATE_MODE:-local}"

if [[ "$gate_mode" != "local" && "$gate_mode" != "handoff" ]]; then
    echo "BROADAPPS_GATE_MODE must be local or handoff."
    exit 1
fi

gate_source_snapshot="$(bash "$platform_root/Scripts/source_snapshot_digest.sh")"
echo "Release source snapshot: $gate_source_snapshot"

gate_report_evidence=""
if [[ "$gate_mode" == "handoff" ]]; then
    gate_report_evidence="$(
        bash "$platform_root/Scripts/report_evidence_digest.sh"
    )"
fi

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

if [[ "$gate_mode" == "handoff" ]]; then
    post_build_report_evidence="$(
        bash "$platform_root/Scripts/report_evidence_digest.sh"
    )"
    if [[ "$post_build_report_evidence" != "$gate_report_evidence" ]]; then
        echo "Agent reports changed during the release build; rerun the gate."
        echo "Started: $gate_report_evidence"
        echo "Ended:   $post_build_report_evidence"
        exit 1
    fi

    echo "[release 5/5] Snapshot-bound PLATFORM_LOCAL agent reports"
    BROADAPPS_EXPECTED_SOURCE_SNAPSHOT="$gate_source_snapshot" \
        BROADAPPS_EXPECTED_REPORT_EVIDENCE="$gate_report_evidence" \
        bash "$platform_root/Scripts/check_handoff_acceptance.sh"
    echo "BroadApps iOS Platform handoff gate passed."
else
    echo "BroadApps iOS Platform local engineering gate passed."
    echo "For final handoff, create fresh reports and use BROADAPPS_GATE_MODE=handoff."
fi
