# ADR-0004: обязательный `ru_pay` и контекст iPhone для RU Billing

- Статус: принято; provenance capability уточнена ADR-0005
- Дата: 2026-08-09
- Обновлено: 2026-08-30

> [!NOTE]
> Обязательный `ru_pay = true`, правило «Storefront **или** регион iPhone», backend-authoritative
> entitlement и запрет выдавать premium после одного возврата из Safari остаются
> в силе. [ADR-0005](0005-provider-managed-remote-feature-gates.md)
> разделяет Special Offer и RU capability; RU сохраняет требование
> `.verifiedFreshRemote`.

## Контекст

RU Billing нужен как опциональный способ оплаты рядом с Apple. Его
доступность определяется флагом Adapty `ru_pay`, App Store Storefront и регионом
iPhone. Платформа не должна разрешать СБП/карту из собственного
кеша или отсутствующего флага.

Legacy backend и cancellation endpoint могут существовать во время миграции,
однако их fallback остаётся отдельным решением и не меняет eligibility.

## Решение

RU methods доступны только при трёх gates:

```text
host feature enabled
AND verified-fresh remote ru_pay == true
AND (App Store Storefront == RU/RUS OR iPhone region == RU/RUS)
```

В последней строке достаточно одного совпадения. Системный язык, клавиатура,
IP, timezone и формат валюты в eligibility не участвуют.

Remote decision имеет четыре состояния: `absent`, `enabled`, `disabled`,
`invalid`. Parser читает все aliases; любой explicit `false` побеждает,
malformed или conflicting values дают `invalid`. Только `enabled` с provenance
Только `.verifiedFreshRemote` может разрешить показ RU methods.
`.providerCacheFallbackPossible`, `.platformCache` и `.legacyUnqualified` не могут включить RU
Billing. Это не финансовая авторизация: оплату и premium подтверждает backend.

Host fallback без явного `ru_pay = true` не поддерживается:

- `absent`, `disabled` и `invalid` всегда выключают feature;
- platform-cache/unqualified `enabled` не показывает RU methods;
- российский Storefront/регион без `ru_pay = true` оставляет только Apple.

Dashboard-generated fallback Adapty имеет
`.providerCacheFallbackPossible` и не авторизует RU Billing, даже если его `ru_pay = true`.

Debug может process-local переопределить только remote gate для
проверки UI. Host template разблокирует store только под `#if DEBUG`;
обычный initializer fail-closed к Adapty. Force modes не обходят
host/device/catalog/backend/entitlement gates.

`SystemRUBillingDeviceContextProvider` читает только
`Locale.current.region?.identifier`, а текущий Storefront приходит через
`StorefrontRepositoryProtocol`. `RUBillingGate` проверяется при построении
способов оплаты и повторно с перезагрузкой Storefront перед внешним checkout.

## Disabled composition

Если RU Billing не настроен:

- используются explicit disabled repositories/use case;
- fake URLs/tokens не создаются;
- `.ruBilling` registration не добавляется в Entitlement Engine;
- UI видит только доступные Apple methods.

Отсутствующий source не должен превращать весь entitlement в вечный unresolved.

## Checkout и entitlement

RU catalog product выбирается deterministic typed matcher, а не guessed
period/SKU. External URL должен быть HTTPS.

```text
create checkout
→ persist app-wide pending context с originating subject, без URL/email/token
→ open external page
→ app реально возвращается active
→ poll server status
→ start unified entitlement generation
→ only active unlocks premium
```

`.opened` и `paid` без active entitlement не выдают доступ. Storefront и регион
решают только, можно ли начать новый RU checkout; они не доказывают покупку и не
используются для восстановления доступа.

## Explicit legacy cancellation fallback

Основной cancellation repository используется всегда первым. Legacy fallback
разрешён только если одновременно:

- `allowsLegacyCancellationFallback == true`;
- host передал explicit legacy path/repository;
- primary outcome имеет `.unavailable` или `.failed`.

`cancelled` и `alreadyInactive` не вызывают legacy endpoint. Нет hidden URL или
автоматического переключения. Cancellation не отзывает paid-through access
немедленно: authoritative status может оставаться active до `expiresAt`.

## Связь с paywall fallback `main`

Paywall может перейти с requested placement на `.main`. Это не обходит RU
gates:

- `ru_pay` берётся из реально resolved payload;
- host feature gate остаётся обязательным;
- RU Storefront или RU-регион iPhone остаётся обязательным;
- mapping в RU catalog остаётся обязательным;
- analytics сохраняет requested и resolved placements.

Provider fallback paywall и entitlement authority fallback — разные решения.

## Последствия

Положительные:

- правило совпадает с production-поведением 5115;
- русского региона или русского языка достаточно, но только вместе с `ru_pay`;
- absent/false/invalid/platform-cache remote config безопасно выключает RU;
- disabled app не получает лишний unresolved entitlement source;
- открытие Safari не считается premium.

Цена решения:

- изменение региона или языка может изменить доступные способы следующей
  оплаты, поэтому gate повторяется непосредственно перед checkout;
- host должен настроить catalog/endpoints/auth/polling;
- migration legacy cancellation требует отдельной временной policy;
- external checkout требует lifecycle callback после реального возврата app
  active.

## Отклонённые варианты

### Использовать App Store storefront как обязательный gate

Отклонён: принятое продуктовое правило использует регион iPhone или первый
системный язык, как в 5115.

### Считать отсутствующий `ru_pay` включённым

Отклонён: частичный или недоступный config не должен раскрывать альтернативную
оплату.

### Всегда регистрировать RU entitlement source

Отклонён: ненастроенный backend делает aggregation unresolved.

### Автоматически пробовать legacy endpoint

Отклонён: скрытая сеть и неоднозначная credential/subject boundary.

### Открытая payment page сразу выдаёт premium

Отклонён: пользователь может закрыть страницу или backend ещё не подтвердил
entitlement.

## Проверка решения

- `ru_pay = true` + RU region + любой язык → matched RU methods;
- `ru_pay = true` + non-RU region + русский язык → matched RU methods;
- `ru_pay = true` + non-RU region + нерусский язык → только Apple;
- `ru_pay = false` + RU region + русский язык → только Apple;
- absent/malformed/conflicting/platform-cache `ru_pay` → только Apple;
- verified-fresh `ru_pay = true` + подходящий region/language → доступные RU methods;
- повторная проверка перед checkout использует актуальный контекст iPhone;
- RU backend disabled → source отсутствует в engine;
- URL open failure очищает pending context;
- Safari return без active → pending/unavailable, не premium;
- primary cancellation success не вызывает legacy;
- legacy вызывается только при explicit flag + primary failure.

Полная настройка: [RU Billing](../RUBilling.md). Remote keys:
[Remote Config](../RemoteConfig.md).
