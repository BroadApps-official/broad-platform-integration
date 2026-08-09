# RU Billing — post-fix отчёт

Дата: 2026-08-09
Вердикт: `BLOCKED`
Source snapshot SHA-256: `4853d9f2ccbc11e7995ba6cb07291cc8770c59effbbb24f3d10a49fe862a26d4`
Reviewed at UTC: `2026-08-09T05:41:55Z`
Acceptance run ID: `1c16dff2-dabd-4998-af40-5645e7b5f49f`
Host bundle IDs: `N/A`

## Команды

- `bash Scripts/validate.sh`
- `bash Scripts/lint.sh`
- `BROADAPPS_GATE_MODE=local bash Scripts/release_gate.sh`

## Проверено

- source/build checks прошли;
- RU storefront gate остаётся live App Store `RU/RUS`, без locale/language fallback;
- catalog cache привязан к subject;
- persisted pending decode повторно валидирует invariants;
- общий operation gate блокирует RU/Apple/restore при active и persisted pending операции;
- remote gate различает absent/enabled/disabled/invalid, проверяет все aliases и не позволяет fallback обойти false/malformed;
- pending RU снимается только terminal backend status, а не изменяемыми часами устройства;
- return coordinator публикует terminal gate status открытому paywall;
- полный BroadApps JSON wire schema зафиксирован в `Documentation/RUBilling.md`.
- app-wide `SubjectAuthorizationSession` выдаёт epoch-bound binding; logout и
  subject switch отзывают старые HTTP/cache/pending/entitlement операции;
- raw checkout/status/polling repositories и use cases больше не входят в
  public services/DI, а foreign pending state наружу виден только как opaque blocker;
- subject/credential proof повторно проверяется после HTTP await и перед
  persistence, cache mutation, cancellation side effect и открытием Safari.

## Findings

Findings: нет в static/build scope.

## Неподтверждённые риски

Нет live RUS storefront, staging backend/auth/test SKU и payment instrument без реального списания. Checkout → Safari return → polling → active, cancel и timeout не прогнаны live; production acceptance заблокирована.

## Итог

Fail-closed локальный RU contract готов; verified-fresh positive gate и live backend/payment приёмка не завершены.
