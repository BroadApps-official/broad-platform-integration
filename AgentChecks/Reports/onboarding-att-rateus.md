# Onboarding, ATT и Rate Us — post-fix отчёт

Дата: 2026-08-09
Вердикт: `BLOCKED`
Source snapshot SHA-256: `4853d9f2ccbc11e7995ba6cb07291cc8770c59effbbb24f3d10a49fe862a26d4`
Reviewed at UTC: `2026-08-09T05:41:55Z`
Acceptance run ID: `1c16dff2-dabd-4998-af40-5645e7b5f49f`
Host bundle IDs: `N/A`

## Команды

- `bash Scripts/check_architecture.sh`
- `bash Scripts/validate.sh`
- `BROADAPPS_GATE_MODE=local bash Scripts/release_gate.sh`

## Проверено

- ATT API ограничен `TrackingAuthorizationAdapter`;
- onboarding scan не нашёл Rate Us/review prompt;
- loader/bootstrap не вызывают ATT;
- first-slide/active-scene/visible-window границы проходят static review и build;
- окно повторно проверяется непосредственно перед request: hidden/alpha/scene
  mismatch отменяют ATT; foreground/background/window notifications обновляют gate;
- delay `<= 0` не обходит lifecycle и трактуется fail-closed как disabled policy.

## Findings

Findings: нет.

## Неподтверждённые риски

Реальный system ATT prompt не запускался в этом post-fix report; host должен проверить Info.plist copy и lifecycle на чистой установке.

## Итог

Обязательные границы onboarding/ATT/Rate Us соблюдены в static/build scope; production-приёмка ждёт real host clean-install prompt.
