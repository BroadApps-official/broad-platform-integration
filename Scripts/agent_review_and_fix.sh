#!/usr/bin/env bash

set -euo pipefail

platform_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$platform_root/Scripts/lib/console.sh"
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
    console_error "Неизвестный аргумент: $mode"
    console_hint "Использование: ./Scripts/agent_review_and_fix.sh [--doctor]"
    exit 2
fi

if ! command -v codex >/dev/null 2>&1; then
    console_error "Codex CLI не найден."
    console_hint "Установите Codex, выполните 'codex login' и повторите команду."
    exit 1
fi

if ! command -v rg >/dev/null 2>&1 || ! rg --version >/dev/null 2>&1; then
    console_error "ripgrep (rg) не найден или заблокирован macOS."
    console_hint "Установите rg через Homebrew либо разрешите его в Privacy & Security."
    exit 1
fi

if ! codex login status >/dev/null 2>&1; then
    console_error "Codex CLI не авторизован."
    console_hint "Выполните 'codex login' и повторите команду."
    exit 1
fi

if [[ ! -s "$platform_root/AGENTS.md" || ! -s "$prompt_path" ]]; then
    console_error "Не найдены обязательные инструкции агента."
    console_hint "Проверьте AGENTS.md и AgentChecks/AUTOMATION_PROMPT.md."
    exit 1
fi

if [[ "$mode" == "--doctor" ]]; then
    console_title \
        "BroadApps iOS Platform · проверка окружения" \
        "Никакой код не меняется, агент не запускается."
    console_success "Codex CLI: $(codex --version)"
    console_success "ripgrep: $(command -v rg)"
    console_success "Авторизация Codex готова"
    console_success "AGENTS.md и automation prompt найдены"
    console_success "Доступ к Mac настроен"
    console_info "Рабочая папка: $platform_root"
    console_rule
    console_success "READY · можно запускать ./Scripts/agent_review_and_fix.sh"
    printf 'Doctor passed.\n'
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

console_title \
    "BroadApps iOS Platform · агент проверки и исправления" \
    "Codex проверит платформу, исправит platform-owned ошибки и повторит gate."
console_info "Доступ к Mac: полный, чтобы Xcode видел Simulator и SDK."
console_info "Границы: только BroadAppsIOSPlatform; reference и реальные платежи не затрагиваются."
console_info "Максимум попыток исправления: $max_attempts"

run_external_gate() {
    console_step 2 2 "Независимая перепроверка после ответа Codex"
    console_hint "Общий wrapper-лог: .build/AgentAutomation/gate.log"
    set +e
    bash "$platform_root/Scripts/agent_gate.sh" 2>&1 | tee "$gate_log_path"
    local gate_status="${PIPESTATUS[0]}"
    set -e
    return "$gate_status"
}

attempt=1
while ((attempt <= max_attempts)); do
    console_step 1 2 "Codex проверяет и исправляет платформу · попытка $attempt/$max_attempts"
    rm -f "$pending_report_path"

    set +e
    codex "${codex_arguments[@]}" < "$prompt_path"
    agent_status=$?
    set -e

    if ((agent_status != 0)); then
        console_error "Codex завершился с кодом $agent_status."
        if [[ -s "$pending_report_path" ]]; then
            console_hint "Последний ответ сохранён: AgentChecks/AutomationReports/latest.pending.md"
        fi
        exit "$agent_status"
    fi

    if [[ ! -s "$pending_report_path" ]]; then
        console_error "Codex завершил работу без отчёта. Результат не принят."
        console_hint "Повторите запуск; PASS без отчёта не считается успешным."
        exit 1
    fi

    console_success "Codex закончил попытку и сохранил предварительный отчёт."
    if run_external_gate; then
        mv "$pending_report_path" "$report_path"
        printf '\n## Независимая проверка wrapper\n\n`PASS` — после ответа агента полный Xcode/live gate повторно прошёл снаружи Codex sandbox.\n' >> "$report_path"
        console_rule
        console_success "PASS · агент и независимая перепроверка завершились успешно"
        console_hint "Отчёт: AgentChecks/AutomationReports/latest.md"
        console_hint "Технический лог: .build/AgentAutomation/gate.log"
        exit 0
    fi

    console_warning "Независимая проверка всё ещё падает. Codex получит ещё одну попытку."
    attempt=$((attempt + 1))
done

console_rule
console_error "BLOCKED · после $max_attempts попыток полный gate всё ещё не проходит."
console_hint "Лог: .build/AgentAutomation/gate.log"
console_hint "Ответ агента: AgentChecks/AutomationReports/latest.pending.md"
console_hint "Откройте первую ошибку в логе и выполните указанный следующий шаг."
exit 1
