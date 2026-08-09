#!/usr/bin/env bash

set -euo pipefail

platform_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
prompt_path="$platform_root/AgentChecks/AUTOMATION_PROMPT.md"
reports_root="$platform_root/AgentChecks/AutomationReports"
report_path="$reports_root/latest.md"
pending_report_path="$reports_root/latest.pending.md"
automation_root="$platform_root/.build/AgentAutomation"
gate_log_path="$automation_root/gate.log"
max_attempts=3
mode="${1:-run}"

# Codex Desktop can expose its own temporary `codex-path/rg`. On some Macs
# Gatekeeper asks to approve that copied binary repeatedly. Prefer the already
# installed Homebrew ripgrep before starting the child Codex process.
if [[ -x /opt/homebrew/bin/rg ]]; then
    export PATH="/opt/homebrew/bin:$PATH"
fi

if [[ "$mode" != "run" && "$mode" != "--doctor" ]]; then
    echo "Usage: $0 [--doctor]"
    exit 2
fi

if ! command -v codex >/dev/null 2>&1; then
    echo "Codex CLI is not installed or is not available in PATH."
    echo "Install Codex, run 'codex login', then repeat this command."
    exit 1
fi

if ! command -v rg >/dev/null 2>&1 || ! rg --version >/dev/null 2>&1; then
    echo "ripgrep (rg) is missing or macOS has blocked it."
    echo "Install it with Homebrew or allow the binary in Privacy & Security."
    exit 1
fi

if ! codex login status >/dev/null 2>&1; then
    echo "Codex CLI is not authorized. Run 'codex login' and repeat."
    exit 1
fi

if [[ ! -s "$platform_root/AGENTS.md" || ! -s "$prompt_path" ]]; then
    echo "Agent instructions are missing."
    exit 1
fi

if [[ "$mode" == "--doctor" ]]; then
    echo "Codex CLI: $(codex --version)"
    echo "ripgrep: $(command -v rg)"
    echo "Authorization: ready"
    echo "Instructions: ready"
    echo "Agent access: danger-full-access (management-approved)"
    echo "Workspace: $platform_root"
    echo "Doctor passed. Run ./Scripts/agent_review_and_fix.sh to start the agent."
    exit 0
fi

mkdir -p "$reports_root" "$automation_root"
rm -f "$pending_report_path"

codex_arguments=(
    exec
    --ephemeral
    --sandbox danger-full-access
    --cd "$platform_root"
    --output-last-message "$pending_report_path"
)

if ! git -C "$platform_root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    codex_arguments+=(--skip-git-repo-check)
fi

codex_arguments+=(-)

echo "Starting Codex review-and-fix cycle..."
echo "The agent has full Mac access by management decision."
echo "AGENTS.md still limits edits to BroadAppsIOSPlatform and forbids commit/push."

run_external_gate() {
    echo "Running the independent full Xcode/live gate after the Codex response..."
    set +e
    bash "$platform_root/Scripts/agent_gate.sh" 2>&1 | tee "$gate_log_path"
    local gate_status="${PIPESTATUS[0]}"
    set -e
    return "$gate_status"
}

attempt=1
while ((attempt <= max_attempts)); do
    echo "Codex attempt $attempt/$max_attempts..."
    rm -f "$pending_report_path"

    set +e
    codex "${codex_arguments[@]}" < "$prompt_path"
    agent_status=$?
    set -e

    if ((agent_status != 0)); then
        echo "Codex exited with status $agent_status."
        if [[ -s "$pending_report_path" ]]; then
            echo "Its last message is preserved at: $pending_report_path"
        fi
        exit "$agent_status"
    fi

    if [[ ! -s "$pending_report_path" ]]; then
        echo "Codex finished without a report. Result is not accepted."
        exit 1
    fi

    echo "Codex finished. Running one independent full Xcode/live gate..."
    if run_external_gate; then
        mv "$pending_report_path" "$report_path"
        printf '\n## Независимая проверка wrapper\n\n`PASS` — после ответа агента полный Xcode/live gate повторно прошёл снаружи Codex sandbox.\n' >> "$report_path"
        echo "Automation passed. Agent report: $report_path"
        exit 0
    fi

    echo "The independent gate is still failing. Codex will receive another correction attempt."
    attempt=$((attempt + 1))
done

echo "Automation stopped after $max_attempts Codex attempts."
echo "Latest external gate log: $gate_log_path"
echo "Latest agent message: $pending_report_path"
exit 1
