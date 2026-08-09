# Monetization — post-fix отчёт

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

- exact Adapty `3.17.3` и Swinject `2.10.0` закреплены;
- strict-concurrency/warnings-as-errors build прошёл;
- placements/main fallback и product 1:1 guardrails прошли;
- concurrent same-placement callers join provider load, но получают уникальные presentation IDs; waiter cancellation не инвалидирует общий load;
- Apple/RU purchase/restore и persisted pending RU используют общий operation gate;
- terminal Apple/RU recovery публикует gate status открытому paywall без повторного `onAppear`;
- special offer требует `.verifiedFreshRemote` и trusted server time; provider/platform/legacy cache и untrusted clock fail-closed;
- remote Bool не проходит Foundation bridge как duration/decimal/string; aliases
  duration проверяются все и должны совпадать;
- trusted server Date захватывается парой с monotonic instant до async persistence,
  поэтому задержка сохранения не продлевает offer; истёкший deadline fail-closed;
- countdown после authorization использует monotonic deadline; host/remote/cache
  duration ограничена 10 годами и не может переполнить `Duration`/UI counter;
- cached purchase rehydration требует exact variation/index/SKU/commercial fingerprint;
- products без valid `Money` сохраняются 1:1, но UI и оба checkout boundaries
  блокируют Apple/RU до финансового вызова;
- generic consumable/unknown purchase намеренно fail-before-charge без durable exactly-once fulfillment adapter.
- entitlement source acceptance повторно проверяется после source/cache await и
  перед финальной публикацией; revoked session не пишет shared cache и не может
  вернуть старый RU assertion;
- RU authorization cache использует bounded physical slot и logical login epoch,
  поэтому late response старой сессии exact-rejected после logout/switch.

## Findings

Findings: нет в static/build scope.

## Неподтверждённые риски

Не выполнены live Adapty activation/placements/cache runtime и Apple StoreKit sandbox purchase/restore с реальным bundle/SKU/tester. Default Adapty transport не доказывает `.verifiedFreshRemote`, поэтому production special offer/RU positive gate требует отдельный host-controlled transport. Для Apple consumables/tokens нет dedicated durable exactly-once fulfillment adapter. Production acceptance заблокирована до реализации этих adapters и live-прогонов.

## Итог

Безопасный локальный core готов; verified-fresh transport, consumable fulfillment и live Apple/Adapty приёмка не завершены.
