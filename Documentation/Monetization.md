# Монетизация: единая точка входа

`BroadMonetization` объединяет Adapty, StoreKit, основной backend и RU billing за typed Domain-контрактами. Этот документ показывает общую сборку. Детали отдельных подсистем вынесены в профильные guides и не дублируются здесь.

## Что получает приложение

`BroadMonetizationServices` содержит готовые functional dependencies и явные
safety-boundaries:

| Сервис | Ответственность |
|---|---|
| `ActivateMonetizationUseCaseProtocol` | один раз подготавливает SDK и subject-bound identity |
| `LoadPaywallUseCaseProtocol` | requested placement, cache и общий fallback `main` |
| `SelectProductUseCaseProtocol` | выбирает точное product occurrence по `ProductPresentationID` |
| `PurchaseSelectedProductUseCaseProtocol` | выполняет checkout и новый entitlement refresh |
| `CheckoutSelectedProductUseCaseProtocol` | provider-neutral router: Apple по умолчанию, Apple/RU при `RUBillingAssembly` |
| `RestorePurchasesUseCaseProtocol` | restore и новый entitlement refresh |
| `MonetizationAnalyticsProtocol` | typed события без raw payload/PII |
| `TrackPaywallEventUseCaseProtocol` | упорядочивает provider lifecycle и best-effort analytics |
| `PaywallPresentationLifecycleProtocol` | владеет release provider paywall/product handles независимо от analytics |
| `MonetizationOperationGate` | один app-wide gate для Apple purchase, restore и RU checkout |
| `PendingApplePurchaseCoordinator?` | foreground/transaction recovery durable Apple intent |

Assembly регистрирует эти контракты только когда host передал готовые services. Без явной конфигурации платформа не создаёт fake SDK/backend зависимости.

`operationGate` создаёт host **один раз на весь процесс** и передаёт в каждую
identity composition. Enabled RU factory получает этот же instance. Gate защищает
не только ViewModel busy-state: durable Apple/RU blockers продолжают блокировать
второй финансовый flow после закрытия экрана, cold launch и login/logout.

## Слои

```text
Presentation (BroadUIFlows)
          ↓ use-case protocols
Application (load/select/purchase/restore/entitlement)
          ↓ repository protocols
Data (orchestration, cache, mapping)
          ↓ client/adapters
Infrastructure (Adapty, StoreKit, URLSession)
```

- Domain не импортирует Adapty, StoreKit, SwiftUI или HTTP DTO.
- Presentation не знает provider placement ID и не получает SDK product.
- Raw SDK/backend error превращается в безопасный `AppError` на границе adapter.
- Host app остаётся владельцем ключей, текстов, URL, placement mappings и feature policies.

[Typed Domain-модели →](MonetizationDomain.md) · [Границы модулей →](ADR/0001-module-boundaries.md)

## 1. Subject и активация

`AdaptyPlatformConfiguration` всегда создаётся для конкретного `EntitlementSubject`. Для авторизованного пользователя `AdaptyIdentityProviderProtocol` должен вернуть identity того же subject; для anonymous допустимо отсутствие identity.

Активация:

- single-flight и idempotent для одной конфигурации;
- не допускает одновременную работу с другим API key/subject;
- передаёт `appAccountToken`, если host его настроил;
- по умолчанию отключает сбор IDFA;
- не показывает ATT и не управляет onboarding;
- не выводит API key/customer identity через `description`, debug reflection или лог.

Создание объекта не активирует SDK. Активация происходит через use case или лениво на adapter-границе.

Загрузка paywall получает конечный timeout из `AdaptyPlatformConfiguration`:
по умолчанию `12` секунд, допустимый диапазон `1...60`. Один budget покрывает
основной запрос и provider fallback.

Вся SDK-facing операция выполняется под composition lease. При смене subject gate
ждёт завершения lease, затем навсегда помечает старый context retirement-token;
старые repositories не могут вернуть SDK к прежней identity. Tombstone-set в
глобальном gate не растёт: permanent retired state живёт на самом старом token и
освобождается вместе с его repositories.

## 2. Typed placements

Логические placements платформы:

| `PlacementID` | Обычное назначение |
|---|---|
| `.onboarding` | initial paywall после onboarding |
| `.main` | общий fallback и основной paywall |
| `.proIcon` | paywall из кнопки или иконки Pro |
| `.settings` | premium из settings |
| `.ctr` | campaign/CTR entry point с provider ID `CTR` |
| `.feature` | закрытая feature |
| `.tokens` | consumable/token catalog |
| `.discount` | скидочное предложение |
| `.specialOffer` | optional special-offer flow |
| `.custom(value)` | app-specific сценарий |

Реальные Adapty IDs принадлежат приложению:

```swift
let registry = AdaptyPlacementRegistry(
    main: AdaptyPlacementID(rawValue: "main"),
    mappings: [
        .onboarding: AdaptyPlacementID(rawValue: "onboarding"),
        .proIcon: AdaptyPlacementID(rawValue: "pro_icon"),
        .settings: AdaptyPlacementID(rawValue: "settings"),
        .ctr: AdaptyPlacementID(rawValue: "CTR"),
        .specialOffer: AdaptyPlacementID(rawValue: "special_offer")
    ]
)
```

Базовые provider IDs для новых приложений — `onboarding`, `pro_icon`, `settings`,
`main`, `CTR`, `special_offer`. В Adapty они сначала связываются с paywall
`main`; уникальная схема конкретного приложения добавляется по его документу в
Kaiten. Дополнительные логические точки остаются typed/custom mappings.

Не передавайте provider ID в `BroadPaywallConfiguration`: экран получает только логический `PlacementID`.

## 3. Загрузка paywall и fallback `main`

`PaywallLoadRequest(placementID:)` автоматически фиксирует `.main` как fallback. Порядок:

```text
requested remote
  ├─ usable products → success
  └─ empty/unavailable → requested cache
                         ├─ usable → success
                         └─ miss → main remote
                                   ├─ usable/empty → result
                                   └─ unavailable → main cache → result/error
```

Для запроса `.main` fallback повторно не выполняется.

`PaywallOrigin` всегда сохраняет:

- `requestedPlacementID` — что попросила feature;
- `resolvedPlacementID` — откуда реально пришёл payload;
- `catalogSource` — Adapty/StoreKit/RU/cache;
- typed `fallbackReason`.

`PaywallPayload.remoteConfigurationProvenance` фиксирует `.verifiedFreshRemote`, `.providerCacheFallbackPossible`, `.platformCache` или `.legacyUnqualified`. Обычный paywall может использовать cache; time-sensitive special offer требует только `.verifiedFreshRemote`.

Кеши разных placements не смешиваются. Перед новой презентацией `LoadPaywallUseCase` сам выдаёт cached payload новые `PaywallPresentationID` и `ProductPresentationID`, чтобы impressions и taps не склеивались. Порядок, количество, дубли и opaque product references при этом не меняются.

Параллельные callers `LoadPaywallUseCase` не инвалидируют друг друга: каждый получает свой достоверный result. Если несколько операций одновременно запрашивают один и тот же Adapty placement, включая общий fallback `main`, repository объединяет их в один in-flight SDK load. Каждый caller при этом получает собственные `PaywallPresentationID` и `ProductPresentationID`, при сохранении того же provider-order, product references и raw objects.

Provider резерва не обязан быть Adapty: достаточно реализации `PaywallRepositoryProtocol`. Общий use case и UI от конкретного источника не зависят.

Adapty repositories одной composition всегда получают один и тот же
`AdaptyRepositoryContext`. У отдельных repository initializers нет скрытого
default context: ручная сборка обязана создать context один раз и передать его в
activation/paywall/purchase/restore/analytics lifecycle. Обычный путь —
`AdaptyMonetizationFactory`, который делает это автоматически.

Каждый context получает process-local monotonic ownership sequence. Если во
время active lease или identity preparation ожидают несколько compositions,
gate допускает только самый новый sequence; более старые tokens навсегда retire
и не могут позднее вернуть SDK к прошлому subject. Временно неудавшаяся самая
новая composition может повторить activation тем же context, пока не появился
реально более новый context. Память gate при этом не растёт от числа переходов.

Исходник диаграммы: [paywall-fallback.mmd](Diagrams/paywall-fallback.mmd).

## 4. Products: строгий контракт 1:1

Для результата `Adapty.getPaywallProducts` выполняется только mapping:

```text
[provider product 0, provider product 1, provider product 2, ...]
                              ↓ 1:1
[MonetizationProduct 0, MonetizationProduct 1, MonetizationProduct 2, ...]
```

Запрещено:

- фильтровать по SKU, product kind, цене или subscription period;
- сортировать по цене/периоду;
- дедуплицировать одинаковые SKU;
- ограничивать количество элементов;
- придумывать title, price или period;
- восстанавливать SDK product по одному `ProductID`.

Каждое вхождение получает:

- уникальный `ProductPresentationID` для SwiftUI/analytics;
- валидный provider SKU как `ProductID`; malformed SKU заменяется
  детерминированным bounded opaque surrogate без raw value, а occurrence
  получает `Money == nil` и не может попасть в checkout;
- opaque `commercialFingerprint` фактических commercial/offer terms;
- opaque `ProductReference`, по которому repository находит точный SDK object.

Opaque SDK object не сериализуется в paywall cache. Если cached presentation
пережила process или raw handle уже released, Apple adapter повторно загружает
resolved placement. Rehydration разрешена только при одновременном exact match:

- `PaywallVariationID` (включая точное совпадение `nil`);
- исходный provider-array `productIndex`;
- SKU `ProductID`;
- непустой opaque `commercialFingerprint`.

Fingerprint детерминированно связывает provider product, variation/index, product
type/access level, price/currency, subscription group/period и offer terms. Он не
заменяет SKU и не показывается/не логируется как UI metadata. Любое изменение или
отсутствие fingerprint, variation, позиции, SKU, цены/периода/offer возвращает
safe retryable `product unavailable`/reload-required **до** `makePurchase`.
Платформа никогда молча не покупает изменившееся предложение и не ищет «похожий»
product только по SKU.

Если provider вернул `[A, B, A]`, UI обязан показать три строки в том же порядке. Paywall поддерживает ноль, один и любое большее количество продуктов. [UI-контракт →](PaywallUI.md).

Отображение и право начать финансовую операцию — разные контракты. Каждое
occurrence остаётся в массиве 1:1, даже если у него нет валидного `Money`, kind
равен `.consumable` или `.unknown`. Shared premium flow считает продукт eligible
только при наличии валидного `Money` и поддерживаемого non-consumable/subscription
kind. Неeligible строка видима, но не выбирается, не становится default и
fail-before-charge отклоняется также в checkout/purchase use cases до Apple/RU
adapter-а.

## 5. Remote config

Remote payload маппится в `RemotePaywallConfiguration`:

- RU billing decision `.absent/.enabled/.disabled/.invalid` по всем aliases;
- soft/hard access policy;
- close delay;
- UI variant;
- optional special-offer block.

Обычные отсутствующие поля могут сохранить последнее валидное значение **для того
же placement**. RU decision и special offer — исключения: они не наследуются.
Любой RU false alias даёт `.disabled`, malformed/conflict без false — `.invalid`;
fallback `.enabled` применяется только к `.absent`, а positive `.enabled` требует
`.verifiedFreshRemote` provenance.

Aliases, типы и правила invalid values: [Remote Config](RemoteConfig.md).

## 6. Purchase, restore и durable recovery

SDK/backend completion и premium entitlement — разные факты.

### Purchase

```text
exact ProductSelection
    → acquire shared operation gate
    → atomic durable intent before provider sheet
    → repository purchase
    → cancelled / pending / failed / completed
    → для completed: entitlement refresh(.startNewGeneration)
    → active ? activated : completedButUnverified
```

- `cancelled` не показывается как техническая ошибка;
- Ask-to-Buy и другой `pending` не закрывают paywall и не удаляют intent;
- provider error с неясным исходом (`outcomeUnknown`) тоже становится `.pending`,
  потому что отсутствие списания не доказано;
- `completedButUnverified` сообщает о завершённой операции, но не выдаёт доступ;
- продукт без валидного `Money`, `.consumable` или `.unknown` отображается как
  любое другое provider occurrence, но standard checkout/purchase use cases
  возвращают safe unsupported-product failure **до provider sheet или RU API**;
- только `.activated(snapshot)` разрешает `subscriptionDidBecomeActive()`.

Generic premium pipeline намеренно не покупает consumables. Для них платформа
даёт отдельный `TokenPurchaseManager`, который не зависит от
`SubscriptionPurchaseManager` и не открывает premium. Перед StoreKit sheet он
атомарно сохраняет intent, после покупки принимает только verified transaction
текущего bundle/ownership, сохраняет signed JWS и отправляет его в app-specific
`TokenFulfillmentRepositoryProtocol`. Backend обязан идемпотентно обработать
`transactionID` и вернуть authoritative balance; клиент никогда не прибавляет
токены локально. Незавершённая доставка восстанавливается через
`recoverPendingPurchase()` на launch и foreground и блокирует повторное списание
через общий `MonetizationOperationGate`.

`SubscriptionPurchaseManager` можно использовать отдельно, без token-протоколов
и token backend. Если приложению нужны оба сценария, оба менеджера собираются
рядом, но остаются независимыми. [Подробная сборка →](PurchaseManagers.md).

`PendingApplePurchaseStore` использует один key на `applicationIdentifier`, но
record хранит originating subject, attempt, SKU, product kind и две фазы:
`.initiated` / `.transactionConfirmed`. Begin — atomic insert-if-missing; переход
фазы и clear — compare-and-set по конкретному attempt. Поэтому пересобранная
identity не может перезаписать/удалить чужой intent. Corrupt/unreadable storage
считается потенциально pending и fail-closed блокирует новую оплату.

Host запускает один `Transaction.updates` listener до Adapty activation. В
`verifiedTransactionUpdated` передаётся только verified transaction точного SKU,
текущего bundle, reason `.purchase`, без revocation/upgrade и с проверенной
ownership policy. Listener ничего не `finish()`-ит: в standard Adapty composition
SDK остаётся единственным владельцем transaction finishing.

На launch и каждом переходе scene в `.active` host вызывает
`pendingApplePurchase.applicationDidBecomeActive()`. Recovery сканирует
`Transaction.unfinished` и `Transaction.all`, поэтому approval, полученный до
listener-а или на cold launch, не теряется. После verified subscription intent
остаётся в `.transactionConfirmed`, пока новый authoritative entitlement refresh
не подтвердит active. Он не может быть abandon-нут.

User acknowledgement никогда не отменяет Ask-to-Buy/outcome-unknown и не очищает
`.initiated` intent. Deprecated `abandonAfterUserConfirmation()` только запускает
повторную reconciliation. Timeout, logout, review boundary, fresh inactive и
кнопка retry сами по себе не доказывают, что списание невозможно. Clear допустим
только после definitive provider cancellation/failure до покупки либо verified
terminal reconciliation; premium product дополнительно ждёт authoritative active.

### Restore

После SDK restore **всегда** запускается новый unified entitlement refresh, даже
если provider restore завершился ошибкой:

| Entitlement | `RestoreOutcome` |
|---|---|
| Любой provider result + current authoritative `active` | `.restored(snapshot)` |
| Provider completed + все authority current `inactive` | `.nothingFound` |
| Provider completed + `unresolved` | `.unavailable(safeError)` |
| Provider failed + нет current `active` | сохраняется `.failed(providerError)` |

Raw profile/receipt сам по себе не закрывает flow. [Полный Entitlement guide →](Entitlements.md).

## 7. Entitlement authorities

Engine объединяет только реально настроенные registrations:

```text
Apple ──────────┐
Primary backend ├─→ active / inactive / unresolved
RU billing ─────┘
```

- любой qualified active побеждает;
- inactive требует явного inactive от каждого настроенного source;
- unresolved сохраняет неопределённость и не отзывает premium ложным образом;
- late response после deadline не меняет snapshot/cache;
- cache изолирован по source и subject fingerprint;
- offline grace применим только к прежнему active в рамках policy.

Adapty profile можно добавить как Apple verifier только когда client гарантирует server-validated freshness. Обычный SDK cache без `fetchedAt` остаётся unqualified.

[Решение ADR →](ADR/0003-entitlement-authority.md).

## 8. RU billing

RU billing — optional adapter chain, не автоматическая замена Apple:

```text
host enabled + verified-fresh ru_pay = true
    + (iPhone region RU/RUS OR first system language starts with ru)
    → match exact RU catalog product
    → Apple / SBP / card methods
```

Регион iPhone и первый системный язык — независимые признаки: одного совпадения
достаточно. IP, timezone и App Store storefront не участвуют в eligibility.
External checkout считается только `.opened`, пока backend и новый общий
entitlement refresh не подтвердили active.

Если feature отключена, используйте disabled adapters и не добавляйте `.ruBilling` authority в engine. [RU Billing guide →](RUBilling.md).

Для production composition используется двухшаговый `RUBillingCompositionFactory`:

1. `makeEntitlementRegistration()` создаёт единственный logical RU source и добавляется в registrations общего engine;
2. после создания engine `makeServices(refreshEntitlement:operationGate:)` собирает catalog, checkout, return polling и cancellation поверх того же refresh boundary и общего Apple/RU financial gate.

Так checkout не создаёт второй entitlement engine и не выдаёт доступ самостоятельно. Example использует `DisabledRUBillingCheckoutMethodsUseCase` и не регистрирует RU source.

## 9. Special offer

Host opt-in начинается с optional configuration:

```swift
let specialOffer: SpecialOfferConfiguration? = appFeatures.specialOffer
```

При `nil` resolver возвращает `.unavailable(.notConfigured)` до обращения к любой зависимости. Нет network, placement, cache, persistence, timer, fallback или UI.

Если configuration есть, gate обязан быть valid/enabled, а provenance — `.verifiedFreshRemote`. Fallback от `.main` требует оба условия. Default Adapty repository ставит `.providerCacheFallbackPossible`, поэтому для campaign нужен host-controlled fresh-remote repository. Display-поля остаются optional.

Timed window/cooldown дополнительно требует app-owned `SpecialOfferClock` с
server-synchronized/rollback-safe временем. Default clock возвращает `.untrusted`:
device wall clock не может открыть или продлить offer. Trusted Date захватывается
вместе с monotonic instant до persistence, а после resolution UI считает остаток
по этому же deadline.

Без effective window duration resolver возвращает `.eligible` и готовый `paywall`:
campaign можно показать без countdown, не выдумывая duration. Presentable result
всегда содержит opaque `presentationAuthorization`, привязанный к тому же
`PaywallPresentationID`:

```swift
guard let payload = resolution.paywall,
      let authorization = resolution.presentationAuthorization
else {
    return
}

let configuration = BroadPaywallConfiguration(
    placementID: payload.origin.requestedPlacementID,
    specialOfferAuthorization: authorization
)
let viewModel = PaywallViewModel(
    configuration: configuration,
    dependencies: dependencies,
    initialPayload: payload
)
```

`initialPayload` исключает повторный placement request. Только совпавшая authorization
разрешает renderer-у прочитать offer metadata и запустить timer; перенос remote
config на другой payload невозможен. Persistence read/write/corruption работает
fail-closed: resolver возвращает `.persistenceUnavailable`, освобождает provider
presentation и не показывает offer. Общий renderer показывает optional badge,
crossed text/value, multiplier, period и countdown только при наличии
соответствующего значения. [Special Offer guide →](SpecialOffer.md).

## 10. Experiments и analytics

Adapty SDK — единственный владелец назначения обычных и cross-placement
вариаций. Платформа не хеширует пользователя, не выбирает сегмент и не хранит
параллельный assignment. Host обязан использовать стабильную Adapty identity и
настроить эксперимент в Adapty Dashboard.

Opaque `variationId` сохраняется по всей цепочке:

```text
Adapty paywall → PaywallPayload.variationID → PaywallAnalyticsContext
               → ProductSelection → PurchaseAnalyticsContext
               → exact raw Adapty product при makePurchase
```

При fallback вариация всегда принадлежит фактически загруженному `resolved`
paywall; app analytics отдельно хранит requested и resolved placement. Для
provider-показа выполняется не более одной локальной попытки
`Adapty.logShowPaywall` на presentation. Если payload восстановлен только из
platform cache и raw `AdaptyPaywall` уже отсутствует, app analytics всё равно
видит сохранённую variation, но обещать доставку provider impression нельзя.
Покупка после cache обязана rehydrate exact variation/index/SKU/fingerprint либо
завершиться безопасной ошибкой до списания.

Typed analytics содержит только app-generated attempt IDs и catalog metadata. В событиях нет email, bearer, payment URL, checkout session ID, user identity и raw error text. Каждый принятый generation entitlement refresh отправляет ровно один `entitlementResolved`: итоговые state/freshness и typed состояния logical sources без subject, receipt или SDK payload.

Рекомендуемая analytics-композиция:

```swift
let destinations = CompositeMonetizationAnalytics(
    destinations: [
        appAnalytics
    ]
)
let analytics = DeduplicatingMonetizationAnalytics(
    destination: destinations
)
```

Provider lifecycle намеренно **не** является analytics destination. Используйте
`services.trackPaywallEvent`: для `.paywallShown/.paywallClosed` он сначала вызывает
`services.paywallPresentationLifecycle`, затем отправляет typed event в
non-blocking analytics. Поэтому зависший или отключённый analytics provider не
может удерживать/преждевременно освобождать StoreKit/Adapty handles.

`PaywallViewModelDependencies` получает эти два объекта из тех же services:
`trackEvent: services.trackPaywallEvent` и
`presentationLifecycle: services.paywallPresentationLifecycle`. Lifecycle
освобождает discarded/cancelled payloads и завершённые presentation; показ и close
для одного ViewModel сериализуются. Если host использует узкие
`TrackPaywallShownUseCase`/`TrackPaywallClosedUseCase`, оба должны получить тот же
`PaywallPresentationLifecycleProtocol`. Analytics destination не используется
для release handles. [Adapty experiments →](Experiments.md).

## 11. DI-сборка

Общий порядок:

```swift
// Cache и gate создаются до первой identity/SDK composition и живут весь process.
let platformCache = VersionedJSONCacheRepository(
    keyValueStore: UserDefaultsKeyValueStore(
        namespace: "com.example.my-app.platform"
    )
)
let operationGate = MonetizationOperationGate()

let factory = AdaptyMonetizationFactory(
    configuration: adaptyConfiguration,
    identityProvider: identityProvider,
    placementRegistry: placementRegistry,
    messages: localizedSafeMessages
)

let analytics = DeduplicatingMonetizationAnalytics(
    destination: CompositeMonetizationAnalytics(
        destinations: [appAnalytics]
    )
)

// Ownership policy/recovery принадлежат текущей subject composition.
let appleOwnershipPolicy: StoreKitEntitlementOwnershipPolicy = .appStoreAccount

let pendingAppleStore = PendingApplePurchaseStore(
    subject: entitlementSubject,
    applicationIdentifier: AppIdentity.bundleIdentifier,
    cache: platformCache
)
let transactionRecovery = StoreKitPendingAppleTransactionRecovery(
    appBundleIdentifier: AppIdentity.bundleIdentifier,
    ownershipPolicy: appleOwnershipPolicy
)
let appPaywallCache = VersionedPaywallCache(
    repository: platformCache,
    subject: entitlementSubject,
    freshTimeToLive: 15 * 60,
    maximumStaleAge: 24 * 60 * 60,
    unavailableError: AppError(
        kind: .unavailable,
        userMessage: "Не удалось открыть сохранённые тарифы.",
        diagnosticCode: "paywall.cache.unavailable",
        isRetryable: true
    )
)

let services = factory.makeServices(
    entitlementRepository: entitlementEngine,
    analytics: analytics,
    paywallCache: appPaywallCache,
    errors: localizedSafeErrors,
    pendingApplePurchaseStore: pendingAppleStore,
    pendingAppleTransactionRecovery: transactionRecovery,
    operationGate: operationGate
)

let customerRecovery = services.makeCustomerAccessRecovery(
    subject: entitlementSubject,
    refreshEntitlement: entitlementEngine,
    recoverTokenAccount: appTokenAccountRecovery,
    loadRUSubscription: optionalRUServices?.checkout.loadSubscriptionStatus
)

let assembly = BroadMonetizationAssembly(
    entitlementEngine: entitlementEngine,
    services: services
)
```

`VersionedPaywallCache` — готовая постоянная реализация. Она изолирует
payload по subject и placement, отличает fresh от stale и не возвращает
каталог старше `maximumStaleAge`. При login/logout создайте новый
subject-bound cache поверх того же app-wide `platformCache`.

`paywallCache` всё ещё optional. Если приложение его не передало, fallback
попробует remote `.main`, но локальный cached fallback отсутствует. Durable
`pendingAppleStore` optional не является: production composition не подменяет его
in-memory реализацией. Полный StoreKit updates/foreground wiring показан в
[Getting Started](GettingStarted.md#storekit-updates-и-recovery). Общий порядок startup и cache
описан в [«Запуск SDK и кеш»](StartupAndCaching.md).

Standard factory имеет fail-fast precondition `observerMode == false`, потому что
Adapty владеет StoreKit purchase/finish. Для `observerMode == true` host собирает
свой StoreKit purchase repository/services и сохраняет те же shared gate, durable
intent, verified transaction bridge и entitlement rules; standard
`AdaptyMonetizationFactory.makeServices` в этом режиме не используется.

## 12. Ручная приёмка

Обязательные сценарии перед подключением приложения:

- requested placement success;
- requested unavailable → requested cache;
- requested empty/cache miss → main remote;
- main unavailable → main cache или safe error;
- 0, 1, 2 одинаковых SKU и 20+ products;
- cached rehydration: exact variation/index/SKU/fingerprint проходит, любое изменение terms fail-before-charge;
- consumable остаётся в UI, но standard generic purchase fail-before-charge;
- token purchase сохраняет intent до sheet, не выдаёт локальный баланс и после
  cold launch повторяет только idempotent backend fulfillment verified JWS;
- clean install после login делает fresh Apple/primary/RU entitlement refresh и
  загружает authoritative token balance; install-local cache не считается
  восстановлением;
- внезапный offline/timeout в любой финансовой точке не запускает повторный
  charge: Apple/RU/token pending сохраняется до reconciliation;
- два concurrent caller одного placement получают два валидных result с уникальными presentation IDs, а cancellation одного waiter не портит общий provider load;
- purchase cancelled/pending/failed/completed-but-unverified/active;
- Ask-to-Buy и ambiguous provider failure переживают cold launch, блокируют второй financial flow и завершаются только после verified transaction + entitlement;
- identity switch не перезаписывает и не очищает чужой Apple/RU pending record;
- user acknowledgement не очищает Ask-to-Buy/outcome-unknown; blocker снимает только definitive pre-purchase cancel/failure или verified terminal reconciliation;
- restore nothing/unavailable/active;
- active одного entitlement source при inactive/unresolved остальных;
- все sources inactive;
- timeout и late active;
- special offer `nil` без побочных обращений;
- `ru_pay = true` + RU region при нерусском языке;
- `ru_pay = true` + русский язык при non-RU region;
- `ru_pay = false` при RU region и русском языке;
- analytics без дублей и чувствительных полей.

Для UI fixtures используйте [BroadAppTemplate](../README.md#example-и-ручные-сценарии). Test targets не добавляются.
