# Remote config paywall

С BroadMonetization 2.0.0 Remote Config приходит только из выбранного provider
paywall плейсмента `main` и преобразуется в typed `RemotePaywallConfiguration`.
Все ключи, включая `ru_pay`, `auto_revenue_view`, `special_offer`,
`experiment_code` и `segment_code`, общие для всех экранов. Конфигурации других
placements не читаются. Продукты, variation, purchase handles и аналитика
показа остаются у фактически показанного placement.

Заполните каждый используемый A/B-вариант и локаль `main` перед переходом
с 1.x. UI не читает словарь и не знает aliases. App может использовать
`RemoteConfigKeyRegistry.broadApps` или собственный registry parser.
Custom repositories обязаны передавать config `main` и честный provenance
с каждым payload, включая Special Offer.

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
    let ruExperiment: RUExperimentMetadata?
}
```

`ruBillingGateDecision` — authoritative typed результат: `.absent`, `.enabled`,
`.disabled` или `.invalid`. `isRUBillingEnabled` оставлен как derived compatibility
view (`true/false/nil`) и не различает absent/invalid, поэтому financial gate
обязан использовать decision. `nil` у остальных обычных полей означает
«валидное значение в payload не найдено»; это не то же самое, что `false`, `0`
или `.soft`.

## Стандартные aliases

Для обычных display-полей parser проверяет aliases слева направо и использует
первое присутствующее значение. RU Billing остаётся отдельным safety-контрактом.
Для Special Offer стандартный registry принимает только точный ключ
`special_offer` и только Foundation boolean. Если backend использует другой
ключ, host передаёт один точный custom key явно.

| Typed field | Стандартные ключи | Допустимое значение |
|---|---|---|
| `ruBillingGateDecision` | `ru_pay`, `pay`, `russian_payment`, `ru_billing` | все aliases; bool/number/boolean string |
| `isAutomaticRevenueViewEnabled` | `auto_revenue_view`, legacy `auto_revnue_view`, `auto_revinue_view` | bool/number/boolean string |
| `accessPolicy` | `hardPaywall`, `hard_paywall`, `isHard`, `is_hard`, `hard` | bool или `hard`/`soft` |
| `closeDelay` | `closeDelay`, `close_delay`, `close_delay_seconds` | конечное число секунд `>= 0` |
| `uiVariantID` | `ui_variant`, `uiVariant` | непустая строка |
| special-offer gate | `special_offer` | только boolean `true` / `false` |
| RU experiment | `experiment_code` + `segment_code` | обе строки 1–64 символа без whitespace/control characters |
| legacy offer window | legacy metadata | игнорируется: окно фиксировано 24 часа |
| legacy offer cooldown | legacy metadata | игнорируется: cooldown фиксирован 24 часа |
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
нулевая/слишком большая legacy duration, конфликтующие duration aliases и
пустой display text считаются invalid и дают `nil` для своего поля. Legacy
duration не является gate и не может выключить валидное
`special_offer = true`.

Special-offer gate fail-closed: только boolean `true` включает offer. `false`,
строка, число, malformed value и отсутствие поля дают `isEnabled == false`.

В Dashboard для пяти общих ключей используйте bool для `ru_pay`,
`auto_revenue_view`, `special_offer` и string для двух RU A/B-кодов.
`auto_revenue_view` передаётся host app как настройка представления;
готовая RU-форма всё равно требует обязательные согласия перед оплатой.

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

`LastValidRemoteConfigurationStore` как общий тип хранит значения по ключу
placement. Adapty adapter 2.0.0 всегда передаёт в него `.main`: это общий config
для экранов одной identity. Другие placements не наполняют этот store.

Для display/navigation полей (`isAutomaticRevenueViewEnabled`, `accessPolicy`,
`closeDelay`, `uiVariantID`) применяется merge:

```text
fresh valid value → заменить предыдущее
fresh field absent/invalid → сохранить предыдущее valid value
```

Это защищает доступный paywall от частичного remote payload. Важно:

- общий config `main` передаётся каждому экрану; config других placements не участвует;
- store находится в памяти и не является бесконечным persistent cache;
- `reset(placementID:)` очищает один placement;
- `resetAll()` используется при смене app identity/configuration;
- initial absence без previous value остаётся `nil`.

Финансовый `ruBillingGateDecision` и campaign gate `specialOffer` — не обычные
retained fields. Они всегда берутся из текущего parsed payload `main` и никогда не
наследуют старый `.enabled`: прошлый gate не может воскресить оплату/кампанию.

RU A/B-коды тоже не сохраняются из прошлого ответа. Если `main` вообще не
ответил, адаптер возвращает отсутствие конфигурации, даже если другой placement
доступен. Если ответил без ключа, это `.absent`; ошибка продуктов не теряет
этот запрет. Конкурентные загрузки разделяют один текущий запрос `main`,
но следующая попытка обновляет его. Загрузка самого `main` повторно использует
тот же paywall для продуктов. Запрос настроек не регистрирует показ.

## Какой cache может управлять feature flags

| Provenance payload | Обычный paywall | `special_offer` capability | `ru_pay` capability |
|---|---:|---:|---:|
| `.verifiedFreshRemote` | да | да | да |
| `.providerCacheFallbackPossible` | да | да | нет |
| `.platformCache` | да | нет | нет |
| `.legacyUnqualified` | да | нет | нет |

`providerCacheFallbackPossible` — текущий результат стандартного Adapty SDK. Он
достаточен для визуального Special Offer, но не доказывает network freshness
для RU Billing. `platformCache` — сохранённая платформой копия всего paywall;
она годится только для безопасного offline UI.

Dashboard-generated fallback-файл Adapty регистрируется через
`Adapty.setFallback(fileURL:)` до активации SDK. Он сохраняет products, variation и
Remote Config для paywall/Special Offer, но не может авторизовать RU Billing.

Эти флаги разрешают только показать функцию. Они не подтверждают подписку,
premium, токены или успешный RU-платёж: финансовый результат всегда проверяет
authoritative entitlement source.

Special Offer и RU Billing получают authority через разные typed
capability. Special Offer допускает provider-managed payload. Обычный RU gate
требует свежий remote payload; отдельный [резерв при сбое](RUProviderFallback.md)
использует временное разрешение текущей попытки и не подменяет provenance.

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

- `nil` — не загружать placement, не читать remote config и не запускать UI;
- non-`nil` — resolver может загрузить placement, но enabled gate и provenance,
  разрешающий Special Offer, всё равно обязательны.

Gate всегда читается из выбранного paywall `main`. После его разрешения
продукты загружаются из отдельного placement `special_offer` с обновлённым main config.
Более новый запрет отменяет первоначальное разрешение; authorization для UI
содержит последние настройки `main`, полученные при загрузке оффера.
Для Special Offer `.verifiedFreshRemote` и `.providerCacheFallbackPossible` разрешены;
`.platformCache` и `.legacyUnqualified` его не разрешают.
Для кампании используется обычный `AdaptyPaywallRepository`: собственный Adapty
REST или отдельный repository не требуется.

При `special_offer = true` resolver проверяет active entitlement и persisted
cadence по trusted clock. Первый подходящий close открывает фиксированное окно
24 часа; от точного конца окна начинается cooldown 24 часа. Внутри окна
resolver возвращает `.active(window)` с готовым paywall.
Готовый payload передаётся через `PaywallViewModel(initialPayload:)`, а
`SpecialOfferResolution.presentationAuthorization` — через
`BroadPaywallConfiguration.specialOfferAuthorization`. Optional badge/crossed
text или value/multiplier/period скрываются по одному, если их нет. Countdown
строится только из authorization, привязанной к тому же presentation,
На нуле countdown закрывает экран и переводит цикл в cooldown. Выключение
флага, подтверждённая purchase или restore сбрасывают state.

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

Обычный путь: host opt-in AND verified-fresh `ru_pay=true` AND
(Storefront RU/RUS OR регион iPhone RU/RUS).

Резерв 1.5.0: host явно подключил `LoadPaywallWithRUFallbackUseCase`, Adapty или
его продукты недоступны, Storefront или регион iPhone RU/RUS → свежий backend.
Успешный ответ с false/invalid/absent закрывает резерв. Если ответа нет вообще,
это не равно отсутствующему полю. SDK-адаптер разбирает конфигурацию до загрузки
продуктов и сохраняет полученный запрет при её ошибке.

Платформенный кеш не восстанавливает разрешение. `providerCacheFallbackPossible`
не переименовывается в fresh. Резерв не создаёт Special Offer или A/B assignment,
не пишет `ru_pay=true`. Русский язык не участвует в проверке региона.
Debug override остаётся только для UI-проверок и не обходит backend/entitlement.
[Подключение и границы резервного сценария](RUProviderFallback.md).

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

Ниже только демонстрационная структура для отключённых feature,
без app-specific ID и цен. Для уже подключённого RU Billing сохраните
согласованное значение `ru_pay` из Adapty Dashboard:

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
- [ ] partial main payload сохраняет только обычные display/navigation поля;
- [ ] конфликтующие флаги остальных placements не меняют config из `main`;
- [ ] reset удаляет retained value;
- [ ] отсутствие всех offer keys даёт `specialOffer == nil`;
- [ ] offer display key без gate даёт disabled, а не enabled;
- [ ] все special-offer gate aliases проверяются; false/malformed/conflict выключают offer;
- [ ] legacy duration/cooldown не влияют на `special_offer = true` и на визуальный 24-часовой цикл;
- [ ] удаление offer gate не восстанавливает прошлую кампанию;
- [ ] fallback `.main` без valid enabled offer gate не включает special offer;
- [ ] absent RU gate при default policy не показывает RU methods;
- [ ] все RU aliases true + `.verifiedFreshRemote` → RU gate enabled;
- [ ] любой false alias → disabled, даже рядом с true/malformed;
- [ ] true + malformed без false → invalid и fail-closed;
- [ ] Dashboard fallback зарегистрирован до Adapty activation, но не авторизует RU;
- [ ] provider-cache/unqualified/platform-cache `.enabled` не авторизует RU;
- [ ] Debug force-on/off работает только в Debug, а Release сохраняет strict provenance gate;
- [ ] backend отклоняет checkout при закрытой feature даже после Debug force-on;
- [ ] unknown UI variant переходит на app default без crash.
