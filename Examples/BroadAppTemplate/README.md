# BroadAppTemplate

`BroadAppTemplate` — запускаемый пример инженерной основы нового приложения. Он
показывает разработчику правильную структуру, рабочий composition root,
маршрутизацию и fixture-состояния. Новое приложение строится поверх тех же
модулей платформы, а демонстрационный UI заменяется экранами конкретного бренда.

Reference-проект — это готовое похожее приложение коллеги из Git-репозитория
компании. Разработчик сначала ищет его в Kaiten и Git компании, а если не может
однозначно выбрать — запрашивает reference у Team Lead или проектного менеджера.
Из него изучаются экраны, поведение, тексты и временные app-owned данные, но не
архитектура. Типов проекта два: при наличии Figma дизайн берётся из неё; при её
отсутствии проект считается no-code и использует согласованный результат Claude
Design или Pencil.
Внешний вид RU-оплаты сверяйте с
[продуктовым визуальным ориентиром](../../README.md#visual-reference).

> Example предназначен только для iPhone и генерируется с
> `TARGETED_DEVICE_FAMILY = 1`. iPad, Mac, Mac Catalyst и visionOS не входят в
> platform scope.

Example показывает полный локальный flow платформы:

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
- технический RU payment fixture без endpoint и реального списания;
- экран RU subscription management до и после отмены;
- safe disabled production RU adapter без fake endpoint/token/`.ruBilling` source.

Example использует локальные monetization fixtures и
`DisabledRUBillingCheckoutMethodsUseCase` для production boundary. Отдельные RU
launch arguments показывают настоящий platform UI, но не отправляют запросы и
не выполняют списания.

Переустановку нельзя честно сымитировать только локальным fixture: token balance и
RU purchases обязаны вернуться из backend того же app account. Готовый
platform-координатор и обязательный backend contract описаны в
[Account Recovery](../../Documentation/AccountRecovery.md). Поведение при обрыве связи
во время любого шага зафиксировано в
[Network Interruptions](../../Documentation/NetworkInterruptions.md).

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
| `-ru-payment-sheet` | технический СБП fixture: две обязательные галочки, чек и сохранённый email; без отдельных строк legal links |
| `-ru-payment-sheet-apple` | Apple выбран; RU consent/receipt поля отсутствуют |
| `-ru-subscription-management` | активная RU подписка, дата и действие отмены |
| `-ru-subscription-cancelled` | подписка активна до даты, автопродление отключено |
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
