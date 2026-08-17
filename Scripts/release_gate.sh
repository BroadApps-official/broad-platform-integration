#!/usr/bin/env bash

set -euo pipefail

platform_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$platform_root/Scripts/lib/console.sh"

logs_root="$platform_root/.build/GateLogs"
step_total="${BROADAPPS_GATE_TOTAL:-4}"
step_offset="${BROADAPPS_GATE_OFFSET:-0}"

if [[ "$step_total" == "4" && "$step_offset" == "0" ]]; then
    console_title \
        "BroadApps iOS Platform · инженерная проверка" \
        "Правила → формат → анализ → сборки"
fi

gate_source_snapshot="$(bash "$platform_root/Scripts/source_snapshot_digest.sh")"
console_info "Снимок исходников: ${gate_source_snapshot:0:12}…"

console_run_logged_step \
    "$((step_offset + 1))" "$step_total" \
    "Правила, архитектура, privacy и документация" \
    "$logs_root/01-validation.log" \
    bash "$platform_root/Scripts/validate.sh"

console_run_logged_step \
    "$((step_offset + 2))" "$step_total" \
    "Форматирование Swift-кода" \
    "$logs_root/02-format.log" \
    bash "$platform_root/Scripts/format.sh" --lint

console_run_logged_step \
    "$((step_offset + 3))" "$step_total" \
    "SwiftLint и границы архитектуры" \
    "$logs_root/03-lint.log" \
    bash "$platform_root/Scripts/lint.sh"

console_run_logged_step \
    "$((step_offset + 4))" "$step_total" \
    "Swift Package и iPhone-сборки Debug/Release" \
    "$logs_root/04-build.log" \
    bash "$platform_root/Scripts/build.sh"

post_build_source_snapshot="$(bash "$platform_root/Scripts/source_snapshot_digest.sh")"
if [[ "$post_build_source_snapshot" != "$gate_source_snapshot" ]]; then
    console_error "Исходники изменились во время сборки. Результат нельзя принимать."
    console_hint "В начале: $gate_source_snapshot"
    console_hint "В конце:  $post_build_source_snapshot"
    console_hint "Дождитесь окончания правок и повторите проверку."
    exit 1
fi

if [[ "$step_total" == "4" && "$step_offset" == "0" ]]; then
    console_rule
    console_success "PASS · локальная инженерная проверка полностью прошла"
    console_hint "Подробные логи: .build/GateLogs/"
else
    console_success "Локальные правила и сборки прошли"
fi
