# Optional Special Offer

## Главное правило

Special offer — опциональная фича проекта, а не обязательная стадия paywall flow.
Проект включает её только передачей `SpecialOfferConfiguration`.

```swift
let result = await resolveSpecialOffer(configuration: appConfiguration.specialOffer)
```

Если `appConfiguration.specialOffer == nil`, use case сразу вернёт:

```swift
.unavailable(.notConfigured)
```

До этого return он не обращается ни к одной зависимости. Не будет:

- запроса placement;
- network или cache read;
- запуска таймера;
- чтения или записи persistence;
- fallback на `main`;
- скрытого UI или default offer.

## Три обязательных условия

Даже когда host-конфиг есть, offer не показывается автоматически. Нужны:

1. загруженный paywall payload;
2. `payload.remoteConfiguration.specialOffer.isEnabled == true`;
3. provenance разрешает provider-managed feature gates:
   `.verifiedFreshRemote` или `.providerCacheFallbackPossible`.

Отсутствующий, невалидный или выключенный remote gate даёт
`.unavailable(.disabledByRemoteConfiguration)`. Прошлое валидное значение не
воскрешает фичу: `LastValidRemoteConfigurationStore` намеренно не мерджит старый
`specialOffer` с новым payload.

| Provenance remote config | Обычный paywall | Special offer |
|---|---:|---:|
| `.verifiedFreshRemote` | да | да, при enabled gate |
| `.providerCacheFallbackPossible` | да | да, при enabled gate |
| `.platformCache` | да | нет |
| `.legacyUnqualified` | да | нет |

Стандартный `AdaptyPaywallRepository` уже является правильным источником для
campaign. Pinned Adapty SDK может прозрачно вернуть свой управляемый cache и не
раскрывает origin в public API, поэтому repository честно ставит
`.providerCacheFallbackPossible`. Это всё ещё текущий ответ Adapty и он может
управлять `special_offer`. Собственный REST-транспорт и отдельный
`PaywallRepositoryProtocol` для Special Offer не нужны.

`.platformCache` означает другое: весь payload восстановила сама платформа из
своего persistent cache. Такой payload можно безопасно показать как обычный
paywall, но он не может заново включить кампанию.

Старые persisted payloads декодируются как `.legacyUnqualified`: их можно показать, но нельзя использовать как свежий campaign gate.

## Placement и fallback

Use case запрашивает placement из `SpecialOfferConfiguration`. Общий paywall loader
может вернуть fallback payload с `main`.

Fallback принимается только когда:

- `origin.requestedPlacementID` всё ещё равен configured offer placement;
- `origin.resolvedPlacementID == .main`;
- remote payload на `main` содержит valid и enabled `specialOffer`;
- provenance разрешает provider-managed gates (`.verifiedFreshRemote` или
  `.providerCacheFallbackPossible`).

Обычный main paywall без special-offer gate не может случайно стать discount-экраном.

## Window и cooldown

Эффективные durations выбираются так:

```text
remote value ?? host configuration value
```

Это не скрытые defaults: оба значения приходят из явной конфигурации.
Единый `SpecialOfferDurationPolicy` принимает только конечные положительные
durations не длиннее 10 лет. Это технический safety limit, намного больший
реальной campaign. Present, но malformed/out-of-range или конфликтующая между
aliases remote duration выключает offer целиком, а не превращает его в untimed и
не включает host fallback.
Persisted active window с недопустимым диапазоном также отклоняется fail-closed.

Любой `windowDuration`, `cooldownDuration` или уже сохранённая временная граница
требует `SpecialOfferClock` с подтверждённым server-synchronized временем. Default
clock возвращает `.untrusted`, поэтому timed offer безопасно скрывается с
`.unavailable(.untrustedTime)`. Нельзя возвращать `.trusted(Date())`: системные
часы устройства изменяемы пользователем. Host adapter должен получить серверное
время либо доказать rollback-safe синхронизацию. `trusted(_:)` сразу связывает
server `Date` с текущим `ContinuousClock.Instant`; эту reading нужно создать в
момент получения серверного значения. Любые последующие `await` на persistence
или lifecycle вычитаются из countdown. Если deadline прошёл во время сохранения,
offer fail-closed не передаётся UI.

| Состояние | Что делает resolver |
|---|---|
| `eligible` | Создаёт active window, если configured duration есть |
| `active` | Возвращает paywall до `expiresAt` |
| `expired` | Оставляет offer завершённым или переводит в cooldown |
| `cooldown` | Не возвращает paywall до `until`, затем может начать новое window |
| `ineligible` | Оставляет user недоступным для offer |

Если window duration нет ни в remote payload, ни в host config, resolver возвращает
`eligible` вместе с paywall: предложение можно показать без countdown. Платформа не
придумывает «24 часа» и не пишет бессрочное окно в persistence.

`PersistedSpecialOfferStateRepository` хранит только `active`, `expired` и `cooldown`.
`eligible` и `unavailable` не пишутся. Snapshot содержит schema version и полный
host config; смена placement/durations не подхватит старое окно.

Persistence работает fail-closed. Ошибка read/write, corrupted entry, schema
mismatch или неуспешный conditional cleanup возвращает
`.unavailable(.persistenceUnavailable)`: offer скрывается, provider presentation
освобождается, а новое окно не создаётся «в памяти». Repository обновляет memory
state только после успешной записи; недоступный key остаётся недоступным до новой
composition вместо опасного повторного старта countdown.

## Подключение к общему paywall UI

Resolver уже вернул проверенный payload, поэтому повторно загружать placement перед
показом не нужно. Передайте его как `initialPayload`, а выданную resolver-ом opaque
`presentationAuthorization` — в `BroadPaywallConfiguration`. Authorization содержит
конкретный `PaywallPresentationID` и optional monotonic countdown; UI применит remote
offer metadata/timer только если оба относятся к одному presentation.

```swift
let result = await resolveSpecialOffer(configuration: appConfiguration.specialOffer)

guard let payload = result.paywall,
      let authorization = result.presentationAuthorization
else {
    return
}

let configuration = BroadPaywallConfiguration(
    placementID: payload.origin.requestedPlacementID,
    specialOfferAuthorization: authorization
)
let viewModel = PaywallViewModel(
    configuration: configuration,
    dependencies: paywallDependencies,
    initialPayload: payload
)
```

Общий UI показывает только реально пришедшие `badge`, crossed price/value,
multiplier и period text. Countdown появляется только когда
`authorization.countdown` не `nil`. `expiresAt` остаётся server-time значением для
диагностики, а runtime countdown и автоматическое истечение используют monotonic
deadline. Любое отсутствующее поле скрывает только свой
элемент. Самостоятельно конструировать/переносить authorization между payloads
нельзя: только `SpecialOfferResolution.presentationAuthorization` доказывает
enabled provider gate для этой презентации.

## Подключение

```swift
let stateStore = UserDefaultsKeyValueStore(
    namespace: "dev.broadapps.my-app.monetization"
)
let stateRepository = PersistedSpecialOfferStateRepository(store: stateStore)
let offerClock = SpecialOfferClock {
    guard let serverDate = await serverTimeSource.currentDate() else {
        return .untrusted
    }
    return .trusted(serverDate)
}
let resolveSpecialOffer = ResolveSpecialOfferUseCase(
    loadPaywallUseCase: services.loadPaywall,
    stateRepository: stateRepository,
    presentationLifecycle: services.paywallPresentationLifecycle,
    clock: offerClock
)
```

`serverTimeSource` — app-owned adapter к доверенному backend time endpoint или к
rollback-detecting synchronization layer. Для offer без window/cooldown clock можно
не передавать: resolver его не читает. Для timed offer отсутствие доверенного
времени — ожидаемый fail-closed результат, а не повод перейти на device clock.
Возвращайте `.trusted(serverDate)` сразу после получения значения: helper сам
фиксирует парный monotonic instant, который переживает дальнейшие async-паузы.

Lifecycle обязателен: resolver освобождает payload при disabled gate, persistence
failure, cooldown/ineligible, cancellation и других ветках, где presentation не
передан UI. Concurrent callers одного placement не получают один provider handle:
второй ждёт завершения первого resolution и затем загружает собственную
presentation.

Пример opt-in конфига без хардкода provider placement ID в UI:

```swift
let specialOffer = SpecialOfferConfiguration(
    placementID: .specialOffer,
    windowDuration: 6 * 60 * 60,
    cooldownDuration: 7 * 24 * 60 * 60
)
```

Логический `PlacementID.specialOffer` приложение связывает с реальным provider ID в
typed placement registry. Экран этот ID не знает.

## Никаких придуманных цен

Платформа не вычисляет и не подставляет:

- зачёркнутую цену;
- зачёркнутое числовое значение;
- множитель цены;
- текст периода;
- бейдж.

Каждое поле остаётся optional. UI показывает его только когда оно реально
пришло в valid remote config. Product array передаётся без фильтрации, сортировки
и дедупликации. UI обязан безопасно обработать любое количество, включая ноль.

## Ошибки и entitlement

Ошибка paywall, remote gate или persistence может только скрыть offer. Resolver не
зависит от `EntitlementRepositoryProtocol`, не записывает entitlement cache и не может
превратить техническую ошибку в active или inactive premium.

Acceptance обязательно включает недоступный time source, полный и частичный
rollback wall clock, relaunch с persisted active window и истечение deadline при
открытом paywall. Во всех сомнительных случаях timed offer скрывается; перевод
часов не увеличивает разрешённое время.
