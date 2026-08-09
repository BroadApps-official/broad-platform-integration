# BroadAppTemplate

> Example предназначен только для iPhone и генерируется с
> `TARGETED_DEVICE_FAMILY = 1`. iPad, Mac, Mac Catalyst и visionOS не входят в
> platform scope.

Минимальное host-приложение показывает полный локальный flow платформы:

```text
launch → onboarding (3 слайда) → adaptive paywall → verified purchase/restore → main
```

## Запуск

Из корня `BroadAppsIOSPlatform`:

```bash
./Scripts/generate_example.sh
open Examples/BroadAppTemplate/BroadAppTemplate.xcodeproj
```

Выберите схему `BroadAppTemplate` и iOS Simulator. Progress сохраняется; чтобы увидеть чистый first run повторно, удалите приложение из Simulator.

Полная проверка package + example:

```bash
./Scripts/lint.sh
./Scripts/build.sh
```

## Что демонстрирует example

- composition root и порядок `Core → Monetization → UIFlows`;
- три конфигурируемых onboarding-слайда;
- ATT только после появления первого слайда;
- paywall для 0, 1 и любого количества продуктов без фильтрации;
- product tap/purchase без opacity/scale/dimming;
- purchase/restore с обязательным fresh entitlement;
- один shared non-blocking → deduplicating → composite analytics pipeline;
- bounded typed recorder и debug-панель без PII/raw SDK data;
- bootstrap/cache/timeout fixtures;
- safe disabled RU billing без endpoint, token и `.ruBilling` source.

Example использует локальные monetization fixtures и `DisabledRUBillingCheckoutMethodsUseCase`. Это не production Adapty/RU configuration.

Для real-catalog smoke доступны две готовые схемы:

- `BroadAppTemplateLiveAdapty5013`;
- `BroadAppTemplateLiveAdapty5109Codex`.

Рабочие bundle/Adapty/placement values хранятся в соответствующих tracked
`.xcconfig`. Дополнительный импорт перед запуском не нужен.

Reference repositories остаются read-only. Live scheme проверяет только Adapty
activation/load/show. StoreKit purchase и restore запрещены company policy и
fail-before-charge.

## Полезные launch arguments

| Аргумент | Сценарий |
|---|---|
| `-app-flow-main-only` | только main |
| `-app-flow-paywall-only` | paywall без onboarding |
| `-live-adapty` | real Adapty catalog; financial calls disabled |
| `-analytics-fixture` | paywall-only flow + typed recording sink |
| `-tracking-disabled` | полный UI smoke без системного ATT prompt |
| `-paywall-empty` | empty paywall |
| `-paywall-one-product` | один продукт + automatic selection |
| `-paywall-two-products` | два продукта в provider order |
| `-paywall-many-products` | 12 products + sticky controls |
| `-paywall-payment-methods` | UI-only Apple/SBP/Card sheet; RU adapter remains disabled |
| `-paywall-failure` | safe load error |
| `-paywall-hard` | hard access policy |
| `-purchase-cancelled` | user cancellation |
| `-purchase-pending` | pending без premium |
| `-purchase-failure` | safe purchase error |
| `-restore-nothing` | restore without active access |
| `-restore-failure` | safe restore error |
| `-entitlement-active` | verified active |
| `-entitlement-inactive` | all configured verifiers inactive |
| `-entitlement-unknown` | unresolved без ложного premium |
| `-entitlement-store-kit-fallback` | StoreKit active при unqualified Adapty cache |
| `-entitlement-timeout` | late active игнорируется после deadline |
| `-bootstrap-degraded` | background timeout, main доступен |
| `-bootstrap-failed-once` | critical failure → manual retry |
| `-bootstrap-seed-cache` | записать stale-cache fixture |
| `-bootstrap-stale-cache` | offline fallback после seed |

## Analytics fixture

Запустите example с `-analytics-fixture -tracking-disabled`, выберите продукт и
завершите fixture purchase. На main нажмите кнопку с инструментами, затем
нажмите `Refresh recorded events` в секции `Recorded analytics` (или используйте
pull-to-refresh). В ней показываются
только typed safe fields: attempt/presentation, logical placement, SKU,
variation, checkout method и safe diagnostic code.

Сценарии `-purchase-pending`, `-purchase-cancelled`, `-purchase-failure` и
`-restore-nothing` позволяют проверить разные terminal events. Кнопка
`Clear recorded events` очищает только bounded in-memory историю.

[Полный analytics contract и ожидаемая последовательность →](../../Documentation/Analytics.md)

Подробный quick start, ожидаемые результаты и команды `simctl`: [корневой README](../../README.md#example-и-ручные-сценарии).
