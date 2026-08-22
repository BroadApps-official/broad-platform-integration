# ADR-0004: обязательный `ru_pay` и контекст iPhone для RU Billing

- Статус: принято; часть решения о provenance заменена ADR-0005
- Дата: 2026-08-09
- Обновлено: 2026-08-22

> [!NOTE]
> Обязательный `ru_pay = true`, правило «регион **или** язык», backend-authoritative
> entitlement и запрет выдавать premium после одного возврата из Safari остаются
> в силе. Требование принимать положительный gate только с
> `.verifiedFreshRemote` заменено
> [ADR-0005](0005-provider-managed-remote-feature-gates.md): текущий стандартный
> Adapty payload с `.providerCacheFallbackPossible` тоже может управлять показом
> RU methods, а `.platformCache` — не может.

## Контекст

RU Billing нужен как опциональный способ оплаты рядом с Apple. В production-
приложении 5115 его доступность определяется флагом Adapty `ru_pay`, регионом
iPhone и первым системным языком. Платформа должна использовать то же правило и
не разрешать СБП/карту из кешированного или отсутствующего флага.

Legacy backend и cancellation endpoint могут существовать во время миграции,
однако их fallback остаётся отдельным решением и не меняет eligibility.

## Решение

RU methods доступны только при трёх gates:

```text
host feature enabled
AND current provider-managed Adapty ru_pay == true
AND (iPhone region == RU/RUS OR first system language starts with ru)
```

В последней строке достаточно одного совпадения. App Store storefront, IP,
timezone и формат валюты в eligibility не участвуют.

Remote decision имеет четыре состояния: `absent`, `enabled`, `disabled`,
`invalid`. Parser читает все aliases; любой explicit `false` побеждает,
malformed или conflicting values дают `invalid`. Только `enabled` с provenance
`.verifiedFreshRemote` или `.providerCacheFallbackPossible` может разрешить
показ RU methods. `.platformCache` и `.legacyUnqualified` не могут включить RU
Billing. Это не финансовая авторизация: оплату и premium подтверждает backend.

Host fallback без явного `ru_pay = true` не поддерживается:

- `absent`, `disabled` и `invalid` всегда выключают feature;
- platform-cache/unqualified `enabled` не показывает RU methods;
- российский регион или русский язык без `ru_pay = true` оставляет только Apple.

`SystemRUBillingDeviceContextProvider` читает
`Locale.current.region?.identifier` и `Locale.preferredLanguages.first`.
`RUBillingGate` проверяется при построении способов оплаты и повторно перед
созданием внешнего checkout.

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

`.opened` и `paid` без active entitlement не выдают доступ. Регион и язык
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
- RU region или русский первый системный язык остаётся обязательным;
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
- provider-managed `ru_pay = true` + подходящий region/language → доступные RU methods;
- повторная проверка перед checkout использует актуальный контекст iPhone;
- RU backend disabled → source отсутствует в engine;
- URL open failure очищает pending context;
- Safari return без active → pending/unavailable, не premium;
- primary cancellation success не вызывает legacy;
- legacy вызывается только при explicit flag + primary failure.

Полная настройка: [RU Billing](../RUBilling.md). Remote keys:
[Remote Config](../RemoteConfig.md).
