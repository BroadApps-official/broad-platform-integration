# ADR-0004: RU billing, storefront и явные fallback

- Статус: принято
- Дата: 2026-08-09

## Контекст

RU billing нужен как optional способ оплаты рядом с Apple, но язык/locale/регион устройства не доказывают App Store market пользователя. Legacy backend и cancellation endpoint также могут существовать во время миграции, однако неявный fallback способен отправить credential или subscription ID не туда.

## Решение

RU methods доступны только при трёх независимых gates:

```text
host feature enabled
AND remote decision allows billing
AND StoreKit.Storefront.current.countryCode == RU/RUS
```

Remote decision имеет четыре состояния: `absent`, `enabled`, `disabled`,
`invalid`. Parser читает все aliases; любой explicit `false` побеждает,
malformed или conflicting values дают `invalid`. `enabled` разрешает RU
только с provenance `verifiedFreshRemote`; provider/platform cache не может
включить финансовую feature. Explicit host fallback применяется
только к genuinely `absent`.

Запрещено использовать для eligibility:

- `Locale.current`;
- preferred language;
- device region;
- IP/timezone;
- формат валюты.

`ru_RU` locale разрешён только для отображения уже загруженной цены RUB.

Default `RUBillingRemoteGateFallbackPolicy` — `.disabled`:

- `disabled` и `invalid` всегда выключают feature;
- `enabled` требует `verifiedFreshRemote` provenance;
- `.enabled` fallback может выбрать только host как осознанную policy и только для `absent`;
- storefront RU/RUS остаётся обязательным при любой policy.

Storefront cache имеет конечный TTL. Missing/stale/unavailable не трактуется как Russian.

## Disabled composition

Если RU billing не настроен:

- используются explicit disabled repositories/use case;
- fake URLs/tokens не создаются;
- `.ruBilling` registration не добавляется в Entitlement Engine;
- UI видит только доступные Apple methods.

Отсутствующий source не должен превращать весь entitlement в вечный unresolved.

## Checkout и entitlement

RU catalog product выбирается deterministic typed matcher, а не guessed period/SKU. External URL должен быть HTTPS.

```text
create checkout
→ persist app-wide pending context с originating subject, без URL/email/token
→ open external page
→ app реально возвращается active
→ poll server status
→ start unified entitlement generation
→ only active unlocks premium
```

`.opened` и `paid` без active entitlement не выдают доступ.
Cache TTL и сравнение server `expiresAt` с изменяемыми часами устройства
не снимают финансовый blocker; его очищает только terminal backend status.

## Explicit legacy cancellation fallback

Основной cancellation repository используется всегда первым. Legacy fallback разрешён только если одновременно:

- `allowsLegacyCancellationFallback == true`;
- host передал explicit legacy path/repository;
- primary outcome имеет `.unavailable` или `.failed`.

`cancelled` и `alreadyInactive` не вызывают legacy endpoint. Нет hidden URL или автоматического переключения.

Cancellation не отзывает paid-through access немедленно: authoritative status может оставаться active до `expiresAt`.

## Связь с paywall fallback `main`

Paywall может перейти с requested placement на `.main`. Это не обходит RU gates:

- remote RU field берётся из реально resolved payload;
- host feature gate остаётся обязательным;
- storefront RU/RUS остаётся обязательным;
- mapping в RU catalog остаётся обязательным;
- analytics сохраняет requested и resolved placements.

Provider fallback paywall и authority fallback — разные решения.

## Последствия

Положительные:

- язык интерфейса не раскрывает недоступный payment method;
- absent remote config безопасно выключает RU;
- disabled app не получает лишний unresolved entitlement source;
- legacy endpoint включается только осознанно;
- открытие Safari не считается premium.

Цена решения:

- при недоступном storefront RU methods скрываются даже у русскоязычного пользователя;
- host должен явно настроить catalog/endpoints/auth/polling;
- migration legacy cancellation требует отдельной временной policy;
- external checkout требует lifecycle callback после реального возврата app active.

## Отклонённые варианты

### Проверять `Locale.current` или язык

Отклонён: это пользовательское оформление, а не StoreKit storefront.

### Считать absent remote gate включённым по умолчанию

Отклонён: частичный config неожиданно раскрывает альтернативную оплату.

### Всегда регистрировать RU entitlement source

Отклонён: ненастроенный backend делает aggregation unresolved.

### Автоматически пробовать legacy endpoint

Отклонён: скрытая сеть и неоднозначная credential/subject boundary.

### Открытая payment page сразу выдаёт premium

Отклонён: пользователь может закрыть страницу или backend ещё не подтвердил entitlement.

## Проверка решения

- RU storefront + host/remote true → matched RU methods;
- non-RU storefront при `ru_RU` locale → только Apple;
- storefront unavailable/stale → только Apple;
- absent remote gate с default policy → только Apple;
- explicit remote false при host fallback enabled → только Apple;
- malformed/conflicting aliases при host fallback enabled → только Apple;
- absent remote gate при explicit host fallback enabled → RU только при live RU storefront;
- RU backend disabled → source отсутствует в engine;
- URL open failure очищает pending context;
- Safari return без active → pending/unavailable, не premium;
- primary cancellation success не вызывает legacy;
- legacy вызывается только при explicit flag + primary failure.

Полная настройка: [RU Billing](../RUBilling.md). Remote keys: [Remote Config](../RemoteConfig.md).
