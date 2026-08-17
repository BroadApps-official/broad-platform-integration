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
    "Пять понятных этапов. При ошибке ниже появятся причина, лог и следующий шаг."

BROADAPPS_GATE_TOTAL=5 \
    bash "$platform_root/Scripts/release_gate.sh"

console_run_logged_step \
    5 5 \
    "Две рабочие Adapty-конфигурации (только сборка)" \
    "$logs_root/05-live-adapty.log" \
    bash "$platform_root/Scripts/check_live_adapty_builds.sh"

console_rule
console_success "PASS · BroadApps iOS Platform полностью проверена"
console_hint "Настоящие purchase, restore и RU-платежи не запускались."
console_hint "Подробные логи: .build/GateLogs/"
printf 'BroadApps iOS Platform agent gate passed.\n'
