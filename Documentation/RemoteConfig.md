# Remote config paywall

Remote config приходит вместе с provider paywall и преобразуется в typed `RemotePaywallConfiguration`. UI не читает словарь и не знает aliases. App может использовать стандартный `RemoteConfigKeyRegistry.broadApps` или передать собственный registry в `RemotePaywallConfigurationParser`.

## Модель

```swift
public struct RemotePaywallConfiguration {
    let isRUBillingEnabled: Bool?
    let ruBillingGateDecision: RemoteRUBillingGateDecision
    let isAutomaticRevenueViewEnabled: Bool?
    let accessPolicy: PaywallAccessPolicy?
    let closeDelay: TimeInterval?
    let uiVariantID: PaywallUIVariantID?
    let specialOffer: SpecialOfferRemoteConfiguration?
}
```

`ruBillingGateDecision` — authoritative typed результат: `.absent`, `.enabled`,
`.disabled` или `.invalid`. `isRUBillingEnabled` оставлен как derived compatibility
view (`true/false/nil`) и не различает absent/invalid, поэтому financial gate
обязан использовать decision. `nil` у остальных обычных полей означает
«валидное значение в payload не найдено»; это не то же самое, что `false`, `0`
или `.soft`.

## Стандартные aliases

Для обычных display-полей parser проверяет aliases слева направо и использует первое
присутствующее значение. RU billing, special-offer gate и timed durations —
намеренные safety-исключения: parser проверяет **все** aliases, чтобы
старый/дублирующий ключ не обошёл kill switch или safety limit.

| Typed field | Стандартные ключи | Допустимое значение |
|---|---|---|
| `ruBillingGateDecision` | `ru_pay`, `pay`, `russian_payment`, `ru_billing` | все aliases; bool/number/boolean string |
| `isAutomaticRevenueViewEnabled` | `auto_revenue_view`, legacy `auto_revnue_view`, `auto_revinue_view` | bool/number/boolean string |
| `accessPolicy` | `hardPaywall`, `hard_paywall`, `isHard`, `is_hard`, `hard` | bool или `hard`/`soft` |
| `closeDelay` | `closeDelay`, `close_delay`, `close_delay_seconds` | конечное число секунд `>= 0` |
| `uiVariantID` | `ui_variant`, `uiVariant` | непустая строка |
| special-offer gate | `specialOffer`, `special_offer`, `specialoffer`, `coupon`, `cupon`, `kupon` | bool/number/boolean string |
| offer window | `specialOfferDurationHours`, `special_offer_duration_hours`, `couponDurationHours`, `coupon_duration_hours` | конечное число часов `> 0`, не более 10 лет |
| offer cooldown | `specialOfferCooldownHours`, `special_offer_cooldown_hours`, `couponCooldownHours`, `coupon_cooldown_hours` | конечное число часов `> 0`, не более 10 лет |
| crossed price text | `specialOfferCrossedPriceText`, `special_offer_crossed_price_text`, `crossedPriceText`, `crossed_price_text` | непустая строка |
| crossed numeric value | `specialOfferCrossedPriceValue`, `special_offer_crossed_price_value`, `crossedPriceValue`, `crossed_price_value` | decimal `> 0` |
| price multiplier | `specialOfferCrossedPriceMultiplier`, `special_offer_crossed_price_multiplier`, `crossedPriceMultiplier`, `crossed_price_multiplier`, `old_price_multiplier` | decimal `> 0` |
| offer badge | `specialOfferBadge`, `special_offer_badge`, `offerBadge`, `offer_badge` | непустая строка |
| offer period text | `specialOfferPeriodText`, `special_offer_period_text`, `periodText`, `period_text` | непустая строка |

Boolean strings распознаются без учёта регистра:

```text
true:  1, true, yes, y, on
false: 0, false, no, n, off, ""
```

Для RU aliases действует точная матрица:

| Все найденные значения | Decision |
|---|---|
| Ни одного alias | `.absent` |
| Все присутствующие значения valid `true` | `.enabled` |
| Есть хотя бы один valid `false` | `.disabled` — kill switch всегда побеждает |
| Нет `false`, но есть malformed/unsupported value | `.invalid` |

Таким образом `true + false` даёт `.disabled`, а `true + malformed` — `.invalid`.
Fallback не исправляет conflict/malformed. Для остальных полей неизвестная строка,
`NaN`, infinity, boolean вместо числа/строки, отрицательная задержка,
нулевая/слишком большая duration,
конфликтующие duration aliases и пустой display text считаются invalid. Обычное
invalid поле даёт `nil`; present invalid
special-offer duration дополнительно ставит `specialOffer.isEnabled == false`, чтобы typo не
превратил timed campaign в бессрочную.

Special-offer aliases используют ещё более простой fail-closed результат: любой
`false` выключает campaign; malformed/conflict без полного набора valid `true` тоже
даёт `isEnabled == false`; отсутствие gate не включает offer.

## Собственный registry

Если существующий backend использует другие ключи, замените только aliases:

```swift
let keys = RemoteConfigKeyRegistry(
    ruBillingGate: ["billing_enabled"],
    automaticRevenueView: ["show_revenue_screen"],
    hardPaywall: ["access_mode"],
    closeDelay: ["close_after_seconds"],
    uiVariant: ["layout"],
    specialOfferGate: ["offer_enabled"],
    specialOfferDurationHours: ["offer_hours"],
    specialOfferCooldownHours: ["offer_cooldown_hours"],
    crossedPrice: ["offer_old_price_text"],
    crossedValue: ["offer_old_price_value"],
    priceMultiplier: ["offer_price_multiplier"],
    specialOfferBadge: ["offer_badge"],
    specialOfferPeriodText: ["offer_period_text"]
)

let parser = RemotePaywallConfigurationParser(keys: keys)
```

Каждая группа должна быть непустой и не содержать одинаковые aliases внутри себя. Конкретные значения остаются app/backend-owned и не хардкодятся в UI.

## Retention последнего валидного значения

`LastValidRemoteConfigurationStore` работает отдельно для каждого логического placement.

Для display/navigation полей (`isAutomaticRevenueViewEnabled`, `accessPolicy`,
`closeDelay`, `uiVariantID`) применяется merge:

```text
fresh valid value → заменить предыдущее
fresh field absent/invalid → сохранить предыдущее valid value
```

Это защищает доступный paywall от частичного remote payload. Важно:

- значения одного placement не переходят в другой;
- store находится в памяти и не является бесконечным persistent cache;
- `reset(placementID:)` очищает один placement;
- `resetAll()` используется при смене app identity/configuration;
- initial absence без previous value остаётся `nil`.

Финансовый `ruBillingGateDecision` и time-sensitive `specialOffer` — не обычные
retained fields. Они всегда берутся из текущего parsed payload и никогда не
наследуют старый `.enabled`: прошлый gate не может воскресить оплату/кампанию.

## Special offer — намеренное исключение

Special offer не наследуется из прошлого payload:

```text
ни одного special-offer ключа → specialOffer = nil
есть offer-ключи, но нет valid gate → specialOffer.isEnabled = false
valid gate = false → disabled
valid gate = true → enabled, остальные поля optional
```

`LastValidRemoteConfigurationStore` всегда берёт `parsed.specialOffer` напрямую и не сохраняет previous special offer при свежем `nil`. Так удалённый gate не может случайно воскреснуть после отключения кампании.

Host-level `SpecialOfferConfiguration?` — ещё более ранний gate:

- `nil` — не загружать placement, не читать remote config, не запускать cache/timer/UI;
- non-`nil` — resolver может загрузить placement, но enabled gate и `.verifiedFreshRemote` provenance всё равно обязательны.

Если special-offer placement ушёл на fallback `.main`, offer допустим только когда payload `.main` содержит валидный enabled block и `remoteConfigurationProvenance == .verifiedFreshRemote`. Default Adapty repository использует `.providerCacheFallbackPossible`, потому что SDK может скрыто вернуть cache. Для campaign нужен host-controlled repository, который доказывает network origin. Platform cache и legacy payload не авторизуют campaign.

Если gate enabled, но effective window duration отсутствует, resolver возвращает
`.eligible` с paywall. Это валидный offer без countdown, а не configuration error.
Если duration/cooldown есть, remote config сам по себе недостаточен: resolver также
требует trusted `SpecialOfferClock`; device `Date()` не считается authorization.
Готовый payload передаётся через `PaywallViewModel(initialPayload:)`, а
`SpecialOfferResolution.presentationAuthorization` — через
`BroadPaywallConfiguration.specialOfferAuthorization`. Optional badge/crossed
text или value/multiplier/period скрываются по одному, если их нет. Countdown
строится только из authorization, привязанной к тому же presentation.

[Полный lifecycle special offer →](SpecialOffer.md)

## Access policy и close delay

`accessPolicy` может быть `.soft` или `.hard`:

- remote valid value имеет приоритет над app default;
- отсутствие remote value использует app configuration/последний valid value по правилам слоя;
- `closeDelay = 0` означает немедленно доступный close;
- положительное значение запускает cancellable delay в ViewModel;
- `nil` не означает `0`;
- empty/error paywall всегда получает safe exit, даже при hard policy.

Presentation не запускает собственный network timeout и не меняет access policy по факту ошибки. [Paywall UI →](PaywallUI.md).

## RU billing gate

Remote field — только одно из трёх условий:

```text
host feature enabled
AND (
    verified-fresh remote decision == enabled
    OR decision == absent + явный host fallback .enabled
)
AND App Store storefront RU/RUS
```

Decision `.enabled` может авторизовать billing только когда payload provenance
равен `.verifiedFreshRemote`. Default Adapty payload имеет
`.providerCacheFallbackPossible`, поэтому cached/unqualified `.enabled` не даёт
RU methods и **не** откатывается к host fallback.

`.disabled` и `.invalid` всегда fail-closed при любой provenance/fallback;
cached/provider `false` безопасно работает как kill switch. Explicit host-owned
`RUBillingRemoteGateFallbackPolicy.enabled` применяется **только** к genuinely
`.absent` decision. Он не переопределяет disabled, invalid, conflicting,
malformed или unqualified enabled. Default fallback `.disabled` оставляет absent
выключенным.

Ни этот parser, ни UI не используют язык, device region или locale для eligibility. [RU Billing →](RUBilling.md).

## UI variants и Adapty experiments

`uiVariantID` — opaque renderer metadata. Parser:

- не назначает experiment cohort или segment;
- не объединяет placements;
- не рандомизирует пользователя;
- не отправляет experiment analytics.

Host выбирает поддерживаемый SwiftUI renderer по `uiVariantID`, а
неизвестный variant должен безопасно перейти на app default. Обычные и
cross-placement experiment assignments выбирает только Adapty SDK. Remote
config не содержит второй cohort authority.

[Experiments →](Experiments.md)

## Пример payload

Ниже только демонстрационная структура без app-specific ID и цен:

```json
{
  "hard_paywall": "soft",
  "close_delay_seconds": 0,
  "ru_pay": false,
  "auto_revenue_view": false,
  "ui_variant": "adaptive-default",
  "special_offer": false
}
```

При `special_offer: false` display-поля кампании игнорируются продуктовой логикой: offer неактивен.

## Ручная приёмка

- [ ] каждый alias отдельно распознаётся;
- [ ] первый присутствующий alias имеет приоритет только для обычных display-групп;
- [ ] valid bool strings работают без учёта регистра;
- [ ] отрицательные/бесконечные/пустые значения не проходят;
- [ ] partial ordinary payload сохраняет last valid value только своего placement;
- [ ] reset удаляет retained value;
- [ ] отсутствие всех offer keys даёт `specialOffer == nil`;
- [ ] offer display key без gate даёт disabled, а не enabled;
- [ ] все special-offer gate aliases проверяются; false/malformed/conflict выключают offer;
- [ ] все duration/cooldown aliases валидны и совпадают; malformed/out-of-range/conflict выключает offer;
- [ ] удаление offer gate не восстанавливает прошлую кампанию;
- [ ] fallback `.main` без valid enabled offer gate не включает special offer;
- [ ] absent RU gate при default policy не показывает RU methods;
- [ ] все RU aliases true + verified provenance → RU gate enabled;
- [ ] любой false alias → disabled, даже рядом с true/malformed и host fallback;
- [ ] true + malformed без false → invalid и fail-closed;
- [ ] host fallback `.enabled` применяется только к `.absent`;
- [ ] unqualified/cached `.enabled` не авторизует RU и не использует fallback;
- [ ] unknown UI variant переходит на app default без crash.
