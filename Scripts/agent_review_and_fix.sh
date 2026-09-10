#!/usr/bin/env bash
set -euo pipefail

platform_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -x /opt/homebrew/bin/rg ]]; then
    export PATH="/opt/homebrew/bin:$PATH"
fi
exec /usr/bin/ruby "$platform_root/Scripts/agent_review.rb" "$@"
