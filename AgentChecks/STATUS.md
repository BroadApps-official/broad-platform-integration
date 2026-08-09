# Текущий статус проверок

Текущий source snapshot:
`78e87726ac619540c38c4389288c7e063d25509386b465468267b4ceafb02069`.

Для него 9 августа 2026 года успешно пройден полный локальный
`Scripts/release_gate.sh`: contracts/privacy/documentation, SwiftFormat,
SwiftLint, architecture/security guards, strict-concurrency package, Debug и
Release Simulator и Release generic iOS device. Archive и `.ipa` не создаются.

Для ежедневной работы добавлен отдельный автоматический review-and-fix cycle:
`Scripts/agent_review_and_fix.sh`. Он запускает Codex, разрешает только
platform-owned локальные исправления, повторяет полный local gate вместе со
сборкой обеих live Adapty configurations и сохраняет понятный runtime-отчёт.
После ответа агента wrapper независимо запускает тот же gate ещё раз. Эта
автоматика не подменяет семь read-only snapshot-bound handoff reviews ниже.
Первый sandbox smoke обнаружил и исправил реальную проблему: Swift module
cache для проверки README GIF теперь создаётся внутри `.build`, поэтому Codex
может стабильно выполнить документационный gate. Следующий smoke перенёс
SwiftPM/Clang, SwiftFormat и Xcode package caches внутрь `.build`.

Для текущего snapshot выполнен полный `agent_review_and_fix` cycle с полным
доступом к Mac. Сам агент и независимый повтор wrapper-а завершили
`Scripts/agent_gate.sh` с `PASS`; обе tracked live Adapty configurations
скомпилированы без запуска приложения, purchase или restore.

По уточнённому решению руководства automation запускает Codex с полным доступом
к Mac: агент сам выполняет Xcode/CoreSimulator и live Adapty builds. Scope
остаётся только `BroadAppsIOSPlatform`, а wrapper после ответа независимо
повторяет полный gate. Также зафиксирован новый platform scope: только iPhone,
без iPad, Mac, Mac Catalyst и visionOS.

На iPhone 17 Pro Simulator вручную пройден `-analytics-fixture`: recorder
подтвердил load/show/selection/purchase/entitlement/close sequence, сохранение
SKU и variation и отсутствие raw/PII полей в debug-представлении.

На изолированном iPhone 17 Pro Simulator live Adapty catalog smoke пройден
отдельно с `5013` и `5109Codex`: SDK активировался, реальные placements и
products загрузились и общий adaptive paywall их показал. Purchase/restore не
вызывались; live scheme обрывает их до финансового SDK-вызова. Временный
симулятор после проверки удалён.

Обе рабочие Adapty-конфигурации теперь tracked и входят в Git/source digest по
требованию руководства. Для них сгенерированы и собраны отдельные schemes
`BroadAppTemplateLiveAdapty5013` и
`BroadAppTemplateLiveAdapty5109Codex`; importer/local ignored config удалены.

Это **local engineering PASS**. Для platform handoff нужны только свежие
snapshot-bound reports; интеграция real apps выполняется позднее.

Семь сохранённых reports относятся к предыдущему snapshot
`4853d9f2ccbc11e7995ba6cb07291cc8770c59effbbb24f3d10a49fe862a26d4`.
После изменений experiment/analytics contracts и recording fixture они имеют статус `STALE` и не
могут подтверждать текущий source. Их содержимое сохранено как история; вручную
подменять digest или verdict нельзя. Упоминания iPad в старых reports также
являются историей прежнего scope; новые audits проверяют только iPhone.

| Направление | Сохранённый report | Статус для текущего snapshot | Что ещё нужно |
|---|---|---|---|
| Architecture | [report](Reports/architecture.md) | `STALE` | повторный read-only audit на exact digest |
| Common UI | [report](Reports/ui.md) | `STALE` | новый source/fixture audit |
| Onboarding/ATT/Rate Us | [report](Reports/onboarding-att-rateus.md) | `STALE` | новый source/fixture audit |
| Adaptive Paywall | [report](Reports/paywall.md) | `STALE` | новый audit + available Simulator fixtures |
| Monetization | [report](Reports/monetization.md) | `STALE` | новый audit + live Adapty catalog smoke без StoreKit charge |
| RU Billing | [report](Reports/ru-billing.md) | `STALE` | новый fail-closed contract audit; real payment out of scope |
| Security | [report](Reports/security.md) | `STALE` | новый secret/importer/privacy audit |

Для platform handoff нужен один новый snapshot-bound review run:

1. повторно выполнить все семь read-only agent prompts для текущего digest;
2. использовать один acceptance UUID и scope `PLATFORM_LOCAL`;
3. подтвердить сохранённые local/live-Adapty smoke evidence;
4. пройти `BROADAPPS_GATE_MODE=handoff ./Scripts/release_gate.sh`.

Формат доказательств описан в
[REPORT_TEMPLATE.md](REPORT_TEMPLATE.md) и
[Platform Handoff](../Documentation/PlatformHandoff.md).
