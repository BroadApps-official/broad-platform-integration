#!/usr/bin/env bash

set -euo pipefail

platform_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$platform_root/Scripts/lib/console.sh"
logs_root="$platform_root/.build/GateLogs"

if [[ -x /opt/homebrew/bin/rg ]]; then
    export PATH="/opt/homebrew/bin:$PATH"
fi

console_title \
    "BroadApps iOS Platform · полная проверка" \
    "Шесть этапов. При ошибке ниже появятся причина, лог и следующий шаг."

BROADAPPS_GATE_TOTAL=6 \
    bash "$platform_root/Scripts/release_gate.sh"

console_run_logged_step \
    5 6 \
    "Две рабочие Adapty-конфигурации (только сборка)" \
    "$logs_root/05-live-adapty.log" \
    bash "$platform_root/Scripts/check_live_adapty_builds.sh"

console_run_logged_step \
    6 6 \
    "App Store сборка без RU-модуля" \
    "$logs_root/06-apple-only.log" \
    bash "$platform_root/Scripts/check_optional_billing.sh"

console_rule
console_success "PASS · локальный platform gate пройден"
console_hint "Scope: платформа, RU-enabled и Apple-only примеры, compile-only live Adapty schemes."
console_hint "Настоящие purchase, restore и RU-платежи не запускались."
console_hint "Подробные логи: .build/GateLogs/"
printf 'BroadApps iOS Platform agent gate passed.\n'
