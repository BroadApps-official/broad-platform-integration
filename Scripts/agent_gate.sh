#!/usr/bin/env bash

set -euo pipefail

platform_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ -x /opt/homebrew/bin/rg ]]; then
    export PATH="/opt/homebrew/bin:$PATH"
fi

echo "[agent gate 1/2] Full local engineering gate"
bash "$platform_root/Scripts/release_gate.sh"

echo "[agent gate 2/2] Both tracked live Adapty build configurations"
bash "$platform_root/Scripts/check_live_adapty_builds.sh"

echo "BroadApps iOS Platform agent gate passed."
