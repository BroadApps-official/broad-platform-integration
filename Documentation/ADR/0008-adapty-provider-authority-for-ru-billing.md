# ADR-0008: Adapty provider authority для RU Billing

- Статус: принято
- Дата: 2026-09-16
- Набор платформы: 4.1.2
- Модуль: BroadMonetization 4.1.0

## Контекст

Стандартный `AdaptyPaywallRepository` получает paywall, продукты и Remote Config
через public Adapty SDK. SDK не сообщает приложению, пришёл ли конкретный payload
из сети, managed cache или Dashboard fallback. Поэтому adapter корректно ставит
`.providerCacheFallbackPossible`, а не `.verifiedFreshRemote`.

Предыдущее правило разрешало RU Billing только для `.verifiedFreshRemote`.
Стандартный Adapty adapter такую provenance не выдавал, поэтому production-путь
`Adapty успешно загрузился → ru_pay=true` всё равно оставался закрытым.

## Решение

Current provider payload авторизует explicit remote gates при двух provenance:

- `.verifiedFreshRemote`;
- `.providerCacheFallbackPossible`.

Это относится независимо к `special_offer=true` и `ru_pay=true`. Положительное
значение одного флага не включает другой. `.platformCache` и
`.legacyUnqualified` не авторизуют ни один gate; `false`, absent, malformed и
conflicting aliases остаются fail-closed.

Dashboard fallback является Adapty-owned provider payload и подчиняется тому же
правилу. Persistent cache BroadMonetization остаётся только источником безопасного
offline UI и не восстанавливает RU authority.

## Неизменённые границы

Remote Config разрешает только показать RU methods. До checkout и после него
независимо проверяются:

- host opt-in и российский Storefront либо регион iPhone;
- свежий backend catalog, authorization и kill switch;
- точное соответствие выбранного тарифа;
- общий financial operation gate и durable pending reconciliation;
- authoritative entitlement после возврата из внешней оплаты.

Ни provider payload, ни Dashboard fallback не подтверждают оплату и не открывают
Premium. Отдельный opt-in резерв при полной недоступности Adapty остаётся описан
в [ADR-0006](0006-ru-provider-outage-fallback.md).

## Проверка

`Scripts/ContractProbes/SpecialOfferCountdownProbe.swift` проверяет, что
`.providerCacheFallbackPossible` сохраняет оба explicit gate, а platform cache
их снимает. `BroadAppTemplate` использует provider-managed provenance в сценарии
`-ru-pay-provider-enabled` и отдельный fail-closed сценарий
`-ru-pay-platform-cache`.
