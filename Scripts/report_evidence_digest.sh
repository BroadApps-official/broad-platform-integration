#!/usr/bin/env bash

set -euo pipefail

platform_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if (($# > 1)); then
    echo "Usage: Scripts/report_evidence_digest.sh [reports-root]"
    exit 1
fi

reports_root="${1:-$platform_root/AgentChecks/Reports}"

REPORTS_ROOT="$reports_root" /usr/bin/ruby -rdigest -e '
  root = ENV.fetch("REPORTS_ROOT")
  names = %w[
    architecture.md
    ui.md
    onboarding-att-rateus.md
    paywall.md
    monetization.md
    ru-billing.md
    security.md
  ]
  digest = Digest::SHA256.new
  names.each do |name|
    path = File.join(root, name)
    digest.update(name)
    digest.update("\0")
    digest.update(File.file?(path) ? Digest::SHA256.file(path).digest : "missing")
  end
  puts digest.hexdigest
'
