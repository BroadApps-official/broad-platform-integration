#!/usr/bin/env bash

# Shared, intentionally small Terminal UI for platform scripts.
# Colours are used only in an interactive Terminal and respect NO_COLOR.

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
    console_reset=$'\033[0m'
    console_bold=$'\033[1m'
    console_dim=$'\033[2m'
    console_blue=$'\033[38;5;75m'
    console_green=$'\033[38;5;42m'
    console_yellow=$'\033[38;5;214m'
    console_red=$'\033[38;5;203m'
    console_gray=$'\033[38;5;245m'
else
    console_reset=""
    console_bold=""
    console_dim=""
    console_blue=""
    console_green=""
    console_yellow=""
    console_red=""
    console_gray=""
fi

console_rule() {
    printf '%s\n' "${console_gray}────────────────────────────────────────────────────────────────────────${console_reset}"
}

console_title() {
    local title="$1"
    local subtitle="${2:-}"

    printf '\n'
    console_rule
    printf '%s%s%s\n' "$console_bold" "$title" "$console_reset"
    if [[ -n "$subtitle" ]]; then
        printf '%s%s%s\n' "$console_gray" "$subtitle" "$console_reset"
    fi
    console_rule
}

console_step() {
    local current="$1"
    local total="$2"
    local title="$3"

    printf '\n%s[%s/%s]%s %s%s%s\n' \
        "$console_blue" "$current" "$total" "$console_reset" \
        "$console_bold" "$title" "$console_reset"
}

console_success() {
    printf '%s✓%s %s\n' "$console_green" "$console_reset" "$1"
}

console_info() {
    printf '%s•%s %s\n' "$console_blue" "$console_reset" "$1"
}

console_warning() {
    printf '%s!%s %s\n' "$console_yellow" "$console_reset" "$1"
}

console_error() {
    printf '%s✗%s %s\n' "$console_red" "$console_reset" "$1" >&2
}

console_hint() {
    printf '  %s→%s %s\n' "$console_gray" "$console_reset" "$1"
}

console_relative_path() {
    local path="$1"
    local root="${platform_root:-}"

    if [[ -n "$root" && "$path" == "$root/"* ]]; then
        printf '%s' "${path#"$root/"}"
    else
        printf '%s' "$path"
    fi
}

console_show_failure_log() {
    local log_path="$1"
    local visible_lines="${CONSOLE_ERROR_TAIL_LINES:-28}"
    local relative_log=""
    relative_log="$(console_relative_path "$log_path")"

    if [[ -s "$log_path" ]]; then
        printf '\n%sПоследние строки ошибки:%s\n' "$console_bold" "$console_reset" >&2
        tail -n "$visible_lines" "$log_path" | sed 's/^/    /' >&2
    else
        console_warning "Команда завершилась без текста ошибки."
    fi

    printf '\n' >&2
    console_hint "Полный лог: $relative_log" >&2
    console_hint "Исправьте причину выше и повторите ту же команду." >&2
}

console_run_logged_step() {
    local current="$1"
    local total="$2"
    local title="$3"
    local log_path="$4"
    shift 4

    mkdir -p "$(dirname "$log_path")"
    console_step "$current" "$total" "$title"
    console_hint "Технический лог: $(console_relative_path "$log_path")"

    local command_status=0
    "$@" >"$log_path" 2>&1 || command_status=$?

    if ((command_status == 0)); then
        console_success "$title — готово"
        return 0
    fi

    console_error "$title — ошибка (код $command_status)"
    console_show_failure_log "$log_path"
    return "$command_status"
}
