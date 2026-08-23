#!/usr/bin/env bash

set -euo pipefail

platform_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$platform_root/Scripts/lib/console.sh"

subsystem="${1:-com.broadapps.platform.template}"
requested_device="${2:-}"

if ! command -v xcrun >/dev/null 2>&1; then
    console_error "Xcode command-line tools не найдены."
    console_hint "Откройте Xcode один раз и повторите команду."
    exit 1
fi

if [[ ! "$subsystem" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,254}$ ]]; then
    console_error "Некорректный subsystem: $subsystem"
    console_hint "Используйте постоянный bundle-style ID без пробелов."
    exit 2
fi

devices_json="$(xcrun simctl list devices available --json)"
booted_devices=()
while IFS= read -r device; do
    [[ -n "$device" ]] && booted_devices+=("$device")
done < <(
    /usr/bin/ruby -rjson -e '
      data = JSON.parse(STDIN.read)
      data.fetch("devices", {}).each_value do |devices|
        devices.each do |device|
          next unless device["isAvailable"] && device["state"] == "Booted"
          next unless device.fetch("deviceTypeIdentifier", "").include?(".iPhone-")
          puts [device.fetch("udid"), device.fetch("name")].join("\t")
        end
      end
    ' <<<"$devices_json"
)

selected_device=""
selected_name=""

if [[ -n "$requested_device" ]]; then
    for device in "${booted_devices[@]}"; do
        device_udid="${device%%$'\t'*}"
        if [[ "$device_udid" == "$requested_device" ]]; then
            selected_device="$device_udid"
            selected_name="${device#*$'\t'}"
            break
        fi
    done

    if [[ -z "$selected_device" ]]; then
        console_error "Указанный iPhone Simulator не запущен: $requested_device"
        console_hint "Запустите его в Xcode/Simulator и повторите команду."
        exit 2
    fi
elif ((${#booted_devices[@]} == 0)); then
    console_error "Нет запущенного iPhone Simulator."
    console_hint "Запустите iPhone Simulator, откройте приложение и повторите команду."
    exit 2
elif ((${#booted_devices[@]} > 1)); then
    console_error "Запущено несколько iPhone Simulator — выберите один UDID."
    for device in "${booted_devices[@]}"; do
        console_hint "${device#*$'\t'}: ${device%%$'\t'*}"
    done
    console_hint "Повторите: bash Scripts/stream_example_logs.sh '$subsystem' <UDID>"
    exit 2
else
    selected_device="${booted_devices[0]%%$'\t'*}"
    selected_name="${booted_devices[0]#*$'\t'}"
fi

console_title \
    "BroadAppTemplate · runtime Console" \
    "Только безопасные typed OSLog-события выбранного приложения."
console_info "Simulator: $selected_name ($selected_device)"
console_info "Subsystem: $subsystem"
console_hint "Остановить поток: Control-C"
console_hint "Источник истины для результата — UI/Debug Status; этот поток объясняет ход выполнения."

exec xcrun simctl spawn "$selected_device" log stream \
    --style compact \
    --level debug \
    --predicate "subsystem == \"$subsystem\"" \
    2> >(
        while IFS= read -r simulator_error; do
            if [[ "$simulator_error" != "getpwuid_r did not find a match for uid "* ]]; then
                printf '%s\n' "$simulator_error" >&2
            fi
        done
    )
