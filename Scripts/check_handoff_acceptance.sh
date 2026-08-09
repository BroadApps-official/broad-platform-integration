#!/usr/bin/env bash

set -euo pipefail

platform_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
expected_snapshot="${BROADAPPS_EXPECTED_SOURCE_SNAPSHOT:-}"
expected_report_evidence="${BROADAPPS_EXPECTED_REPORT_EVIDENCE:-}"
acceptance_run_id="${BROADAPPS_ACCEPTANCE_RUN_ID:-}"

current_snapshot="$(bash "$platform_root/Scripts/source_snapshot_digest.sh")"
current_report_evidence="$(bash "$platform_root/Scripts/report_evidence_digest.sh")"

if [[ ! "$acceptance_run_id" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$ ]]; then
    echo "Set BROADAPPS_ACCEPTANCE_RUN_ID to one canonical lowercase UUID."
    exit 1
fi
if [[ -z "$expected_snapshot" || "$expected_snapshot" != "$current_snapshot" ]]; then
    echo "Handoff source snapshot does not match the release gate snapshot."
    exit 1
fi
if [[ -z "$expected_report_evidence" || "$expected_report_evidence" != "$current_report_evidence" ]]; then
    echo "Handoff report evidence does not match the release gate snapshot."
    exit 1
fi

/usr/bin/ruby -rtime - "$platform_root" "$current_snapshot" "$acceptance_run_id" <<'RUBY'
root = File.expand_path(ARGV.fetch(0))
expected_snapshot = ARGV.fetch(1)
expected_run_id = ARGV.fetch(2)
names = %w[architecture ui onboarding-att-rateus paywall monetization ru-billing security]
failures = []
now = Time.now.utc

def one_value(text, pattern, label, failures, path)
  matches = text.scan(pattern).flatten
  if matches.count != 1
    failures << "#{path}: expected exactly one #{label}"
    return nil
  end
  matches.first
end

names.each do |name|
  relative = "AgentChecks/Reports/#{name}.md"
  path = File.join(root, relative)
  unless File.file?(path)
    failures << "#{relative}: missing report"
    next
  end

  text = File.read(path, encoding: "UTF-8")
  verdict = one_value(
    text,
    /^Вердикт: `([^`]+)`$/,
    "verdict",
    failures,
    relative
  )
  snapshot = one_value(
    text,
    /^Source snapshot SHA-256: `([0-9a-f]{64})`$/,
    "source snapshot",
    failures,
    relative
  )
  reviewed_at = one_value(
    text,
    /^Reviewed at UTC: `([^`]+)`$/,
    "reviewed-at timestamp",
    failures,
    relative
  )
  run_id = one_value(
    text,
    /^Acceptance run ID: `([^`]+)`$/,
    "acceptance run ID",
    failures,
    relative
  )
  scope = one_value(
    text,
    /^Review scope: `([^`]+)`$/,
    "review scope",
    failures,
    relative
  )

  failures << "#{relative}: verdict must be PASS" unless verdict == "PASS"
  failures << "#{relative}: stale source snapshot" unless snapshot == expected_snapshot
  failures << "#{relative}: wrong acceptance run ID" unless run_id == expected_run_id
  failures << "#{relative}: review scope must be PLATFORM_LOCAL" unless scope == "PLATFORM_LOCAL"

  begin
    timestamp = Time.iso8601(reviewed_at.to_s).utc
    failures << "#{relative}: future timestamp" if timestamp > now + 300
    failures << "#{relative}: report is older than seven days" if timestamp < now - 7 * 86_400
  rescue ArgumentError
    failures << "#{relative}: invalid reviewed-at timestamp"
  end

  %w[Команды Проверено Findings Неподтверждённые\ риски Итог].each do |heading|
    failures << "#{relative}: missing ## #{heading}" unless text.include?("## #{heading}")
  end
end

if failures.any?
  warn failures.join("\n")
  exit 1
end

puts "Fresh PLATFORM_LOCAL agent reports are valid for the current snapshot."
RUBY

for configuration in Adapty5013.xcconfig Adapty5109Codex.xcconfig; do
    if [[ ! -s "$platform_root/Examples/BroadAppTemplate/Configuration/$configuration" ]]; then
        echo "Tracked Adapty configuration is missing: $configuration"
        exit 1
    fi
done

echo "BroadApps iOS Platform handoff evidence is valid."
