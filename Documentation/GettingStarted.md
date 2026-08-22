# Быстрый старт

> [!IMPORTANT]
> **После скачивания не ищите `.xcodeproj` в корне.** Корень — это Swift
> Package, его файл сборки называется `Package.swift`. Запускаемый пример лежит
> в `Examples/BroadAppTemplate/BroadAppTemplate.xcodeproj`. Чтобы сразу открыть
> его, выполните из корня репозитория:
>
> ```bash
> open Examples/BroadAppTemplate/BroadAppTemplate.xcodeproj
> ```

> Platform policy: приложения предназначены только для iPhone. В host target
> установите `TARGETED_DEVICE_FAMILY = 1`. iPad, Mac, Mac Catalyst и visionOS
> не входят в поддерживаемый scope BroadApps iOS Platform.

Эта инструкция доводит новое приложение от подключения package из GitHub или
локальной checkout-папки до рабочего маршрута
`launch → onboarding → paywall → purchase/restore → main`. Сначала запустите
технический example, затем переносите те же границы в свой composition root.
Example показывает сборку и состояния платформы, но не задаёт продуктовый дизайн
вашего приложения.

## 1. Что требуется

| Инструмент | Требование | Зачем |
|---|---:|---|
| Xcode | 16+ | iOS 17 SDK и Swift 6 toolchain |
| Deployment target | iOS 17+ | минимальная версия package |
| Swift language mode | 5 | режим исходников платформы и example |
| XcodeGen | `2.45.4` | генерирует `.xcodeproj` example; другую версию scripts отклоняют |
| SwiftLint | `0.62.2` | строгий lint; другую версию scripts отклоняют |
| SwiftFormat | локальный installer | `Scripts/install_swiftformat.sh` ставит pinned-версию в `.build/tooling` и проверяет SHA-256 |

Проверка окружения:

```bash
xcodebuild -version
xcodegen --version
swiftlint version
```

## 2. Сначала запустите example

Из корня `BroadAppsIOSPlatform`:

```bash
./Scripts/generate_example.sh
open Examples/BroadAppTemplate/BroadAppTemplate.xcodeproj
```

Выберите схему `BroadAppTemplate` и любой iOS Simulator. Чистый запуск показывает
три **демонстрационных** onboarding-слайда, adaptive paywall и main после
подтверждённой fixture-покупки. Три — не лимит платформы: launch arguments
`-onboarding-one-page`, `-onboarding-two-pages`, `-onboarding-four-pages`,
`-onboarding-long` и `-onboarding-custom-ui` показывают остальные варианты.
`-onboarding-disabled` пропускает flow без ATT, а `-onboarding-invalid`
проверяет безопасное завершение пустой конфигурации без UI и ATT.

Полная локальная проверка:

```bash
./Scripts/lint.sh
./Scripts/build.sh
```

`lint.sh` запускает SwiftLint и проверку границ модулей. `build.sh` собирает package с `strict-concurrency=complete` и `warnings-as-errors`, затем example в Debug Simulator, Release Simulator и unsigned Release `iphoneos`. После device-build он проверяет, что `PrivacyInfo.xcprivacy` реально попал в `.app`. Test targets намеренно отсутствуют.

Если вы меняли код самой платформы, выполните обязательную проверку
по [инструкции Agent Automation](AgentAutomation.md). Внутри уже открытого
Codex/Claude используется `./Scripts/agent_gate.sh`; автоматический
`agent_review_and_fix.sh` запускается отдельно из Terminal, а не изнутри
другого агента.
[Короткий checklist перед передачей изменений →](PlatformHandoff.md).

## 3. Подключите package

### Вариант A — из GitHub

В Xcode откройте:

```text
File → Add Package Dependencies…
```

Укажите URL:

```text
https://github.com/BroadApps-official/BroadCore.git
```

До появления version tag выберите dependency rule `Branch` и укажите
`vers_niiaz`. Репозиторий приватный, поэтому GitHub-аккаунту
разработчика нужен доступ к организации `BroadApps-official`.

Если host сам является Swift Package:

```swift
dependencies: [
    .package(
        url: "https://github.com/BroadApps-official/BroadCore.git",
        branch: "vers_niiaz"
    )
]
```

После согласования version tag branch dependency заменяется на
`from: "1.0.0"`.

### Вариант B — локальная checkout-папка

В Xcode откройте:

```text
File → Add Package Dependencies… → Add Local…
```

Выберите папку `BroadAppsIOSPlatform`, затем добавьте нужному app target продукты:

- `BroadCore`;
- `BroadMonetization`;
- `BroadUIFlows`;
- `BroadExtensions` — опционально, если нужны общие helpers.

Если host сам является Swift Package, используйте относительный путь:

```swift
dependencies: [
    .package(path: "../BroadAppsIOSPlatform")
]
```

В обоих вариантах добавьте нужному iPhone target основные продукты:

- `BroadCore`;
- `BroadMonetization`;
- `BroadUIFlows`.

`BroadExtensions` не является скрытой зависимостью платформы. Добавляйте его
отдельно только тем target, которым нужны Hex Color, custom fonts, dismiss
keyboard или scoped swipe-back.

Не копируйте исходники модулей в app target: иначе исчезнут проверяемые границы зависимостей.

## 4. Создайте один composition root

Только composition root должен:

- читать app-owned configuration;
- создавать adapters/repositories/use cases;
- собирать `BroadCoreAssembly`, `BroadMonetizationAssembly`, `BroadUIFlowsAssembly`;
- передавать ViewModel во View через `init`.

Базовый порядок assembly важен:

```swift
let assembler = Assembler([
    BroadCoreAssembly(
        bootstrapSteps: bootstrapSteps,
        bootstrapErrorMessages: bootstrapMessages,
        logger: appLogger
    ),
    BroadMonetizationAssembly(
        entitlementEngine: entitlementEngine,
        services: monetizationServices
    ),
    BroadUIFlowsAssembly()
])
```

`BroadMonetizationAssembly` ожидает зарегистрированный `BroadCoreModule`, а `BroadUIFlowsAssembly` — `BroadMonetizationModule`.

## 5. Настройте Core

Разделите startup-работу на ограниченные шаги:

- `critical` — без результата нельзя выбрать первый безопасный route;
- `background` — может продолжаться после открытия интерфейса;
- каждый шаг имеет конечный timeout;
- retry задаётся явно, а не бесконечным циклом.

ATT не входит в bootstrap. Loader никогда не запрашивает tracking permission.

Для небольших typed snapshots можно использовать стандартный `VersionedJSONCacheRepository`. Secrets, bearer, payment URL и персональные данные в этот cache не кладутся.

Durable financial state должен использовать один стабильный app-wide store, а не
in-memory fixture:

```swift
let keyValueStore = UserDefaultsKeyValueStore(
    namespace: "com.example.my-app.platform"
)
let platformCache: any CacheRepositoryProtocol = VersionedJSONCacheRepository(
    keyValueStore: keyValueStore,
    logger: appLogger
)
```

Если приложение подменяет `KeyValueStoreProtocol` или `CacheRepositoryProtocol`,
его conditional `write/remove` и `insertIfMissing/replace/remove(ifMatching:)`
обязаны быть настоящими atomic compare-and-set операциями. Иначе две identity
composition могут перезаписать или удалить чужой pending payment.

Готовая практическая схема: [запуск SDK и кеш](StartupAndCaching.md).
Детальные контракты: [Bootstrap](Bootstrap.md),
[Caching & Offline](CachingAndOffline.md), [Logging](Logging.md).

## 6. Соберите Entitlement Engine

Добавляйте только реально настроенные авторитетные источники:

```swift
let registrations: [EntitlementSourceRegistration] = [
    appleRegistration,
    primaryBackendRegistration
] + optionalRUBillingRegistration

let entitlementEngine = EntitlementEngine(
    registrations: registrations,
    subject: entitlementSubject,
    cache: entitlementCache,
    timeoutPolicy: .seconds(3)
)
```

Ключевые правила:

- любой пригодный `active` побеждает;
- `inactive` возможен только когда все настроенные источники явно inactive;
- timeout/offline/invalid/unverified означают `unresolved`;
- отключённый RU billing не добавляет вечный unresolved source;
- Apple premium catalog содержит текущие **и исторические** SKU, но не фильтрует paywall products.

Полная конфигурация и freshness policies: [Entitlements](Entitlements.md).

## 7. Соберите монетизацию

### Placements

Приложение связывает логические placements с реальными provider ID:

```swift
let placementRegistry = AdaptyPlacementRegistry(
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

`.main` обязателен: это общий fallback. Это базовый набор новых приложений;
уникальные placements добавляются по документу проекта через typed/custom
mapping. Provider ID не должны попадать в View или shared screen configuration.

### Adapty services

Ключ и access level передаются host-приложением во время выполнения:

```swift
// App-lifetime dependency: создаётся до первой subject/SDK composition.
let financialOperationGate = MonetizationOperationGate()

guard let adaptyConfiguration = AdaptyPlatformConfiguration(
    apiKey: runtimeConfiguration.adaptyKey,
    accessLevelID: runtimeConfiguration.premiumAccessLevel,
    subject: entitlementSubject,
    paywallLoadTimeout: 12
) else {
    preconditionFailure("Invalid app-owned Adapty configuration")
}

let factory = AdaptyMonetizationFactory(
    configuration: adaptyConfiguration,
    identityProvider: identityProvider,
    placementRegistry: placementRegistry,
    messages: safeLocalizedMessages
)

let appleOwnershipPolicy: StoreKitEntitlementOwnershipPolicy = .appStoreAccount
let pendingApplePurchaseStore = PendingApplePurchaseStore(
    subject: entitlementSubject,
    applicationIdentifier: AppIdentity.bundleIdentifier,
    cache: platformCache
)
let pendingAppleTransactionRecovery = StoreKitPendingAppleTransactionRecovery(
    appBundleIdentifier: AppIdentity.bundleIdentifier,
    ownershipPolicy: appleOwnershipPolicy
)

let paywallCacheError = AppError(
    kind: .unavailable,
    userMessage: "Не удалось открыть сохранённые тарифы.",
    diagnosticCode: "paywall.cache.unavailable",
    isRetryable: true
)
let appPaywallCache = VersionedPaywallCache(
    repository: platformCache,
    subject: entitlementSubject,
    freshTimeToLive: 15 * 60,
    maximumStaleAge: 24 * 60 * 60,
    unavailableError: paywallCacheError
)

let services = factory.makeServices(
    entitlementRepository: entitlementEngine,
    analytics: monetizationAnalytics,
    paywallCache: appPaywallCache,
    errors: safeFlowErrors,
    pendingApplePurchaseStore: pendingApplePurchaseStore,
    pendingAppleTransactionRecovery: pendingAppleTransactionRecovery,
    operationGate: financialOperationGate
)
```

`applicationIdentifier` должен быть стабильным для приложения; bundle identifier —
обычный выбор. Pending record имеет один app-wide key, но хранит originating subject.
При login/logout создайте новый subject-bound store и services поверх **того же**
`financialOperationGate` и cache. Atomic insert/replace/remove не позволяют новой
identity перезаписать или очистить незавершённую операцию старой; unreadable/corrupt
state fail-closed блокирует новый платёж.

Standard `AdaptyMonetizationFactory.makeServices` требует
`AdaptyPlatformConfiguration(observerMode: false)`. Если приложение использует
Adapty observer mode, не вызывайте этот factory для purchase: host обязан внедрить
собственную StoreKit purchase composition с теми же durable pending, gate и
entitlement-инвариантами.

Reference example хранит согласованные client-visible Adapty public SDK keys в
tracked `.xcconfig`. Не выводите их в логи и не смешивайте с backend credentials.
`AdaptyPlatformConfiguration` и identity redacted при reflection.

`AdaptyPaywallRepository` передаёт каждый product один к одному, сохраняя provider
order, дубликаты и consumables. UI identity — `ProductPresentationID`, purchase
handle — opaque `ProductReference`. Cached handle rehydration требует exact
variation + provider index + SKU + opaque commercial fingerprint (включая
price/period/offer terms); mismatch завершается safe failure до charge. Standard
premium purchase use case не покупает consumables: для tokens нужен отдельный
host-owned durable exactly-once fulfillment flow.

### StoreKit updates и recovery

Создайте ровно один listener `Transaction.updates` на весь процесс **до** вызова
`services.activate()`. В bridge пропускаются только JWS-verified transactions
текущего bundle, с reason `.purchase`, без revocation/upgrade и с той же ownership
policy, что использует Apple entitlement verifier/recovery:

```swift
import StoreKit

actor PendingApplePurchaseBridgeTarget {
    private var coordinator: PendingApplePurchaseCoordinator?
    private var ownershipPolicy: StoreKitEntitlementOwnershipPolicy?

    func install(
        _ coordinator: PendingApplePurchaseCoordinator?,
        ownershipPolicy: StoreKitEntitlementOwnershipPolicy
    ) {
        self.coordinator = coordinator
        self.ownershipPolicy = ownershipPolicy
    }

    func receive(_ transaction: Transaction) async {
        guard transaction.appBundleID == AppIdentity.bundleIdentifier,
              transaction.reason == .purchase,
              transaction.revocationDate == nil,
              !transaction.isUpgraded,
              let ownershipPolicy
        else {
            return
        }
        if case let .appAccountToken(expected) = ownershipPolicy,
           transaction.appAccountToken != expected {
            return
        }
        _ = await coordinator?.verifiedTransactionUpdated(
            VerifiedApplePurchaseTransaction(
                productID: ProductID(rawValue: transaction.productID),
                purchaseDate: transaction.purchaseDate,
                reason: .purchase
            )
        )
    }
}

// target и task принадлежат app lifetime, а не user composition.
await applePendingBridgeTarget.install(
    services.pendingApplePurchase,
    ownershipPolicy: appleOwnershipPolicy
)

if appleTransactionUpdatesTask == nil {
    appleTransactionUpdatesTask = Task {
        for await result in Transaction.updates {
            guard case let .verified(transaction) = result else {
                continue
            }
            await applePendingBridgeTarget.receive(transaction)
        }
    }
}

_ = await services.pendingApplePurchase?.applicationDidBecomeActive()
_ = await services.activate()
```

`applePendingBridgeTarget` и `appleTransactionUpdatesTask` создаются один раз в
app-lifetime owner. При login/logout заменяется только установленный coordinator;
вместе с ним заменяется current ownership policy, а второй `Transaction.updates`
loop не стартует. Bridge **не вызывает
`transaction.finish()`**: в standard composition владельцем завершения остаётся
Adapty. На каждом реальном
переходе scene в `.active` снова вызывайте
`services.pendingApplePurchase?.applicationDidBecomeActive()` — recovery проверит
`Transaction.unfinished` и `Transaction.all`, включая approval до запуска listener-а.

Ask-to-Buy и provider error, для которого adapter не может доказать отсутствие
списания, возвращаются как `.pending`; durable intent остаётся и блокирует purchase,
restore и RU checkout. Не очищайте его по timeout/logout и не предлагайте кнопку
«сбросить pending»: user acknowledgement не доказывает отмену операции.
`abandonAfterUserConfirmation()` deprecated и только повторно запускает recovery,
не удаляя record. Blocker снимается лишь при definitive provider
cancellation/failure до покупки либо после verified terminal transaction
reconciliation (и authoritative entitlement для premium product).

### Fresh install и переустановка

После восстановления app login создайте ту же subject composition и запустите
единый recovery до выбора premium route:

```swift
let recovery = services.makeCustomerAccessRecovery(
    subject: entitlementSubject,
    refreshEntitlement: entitlementEngine,
    recoverTokenAccount: appTokenAccountRecovery,
    loadRUSubscription: ruServices.checkout.loadSubscriptionStatus
)

let snapshot = await recovery()
```

Apple subscription проверяется через fresh entitlement generation. Токены и RU
purchase возвращаются только из backend текущего app account. Не переносите
`UserDefaults`-флаги между установками и не пытайтесь восстановить consumable
tokens через StoreKit Restore. [Полный порядок →](AccountRecovery.md).

Не запускайте purchase/checkout автоматически по событию восстановления сети.
Idempotent reads можно повторить bounded policy, а неизвестный финансовый
результат сначала требует pending/status/transaction reconciliation.
[Network-loss guide →](NetworkInterruptions.md).

Подробности: [Monetization](Monetization.md), [Remote Config](RemoteConfig.md), [Paywall UI](PaywallUI.md).

## 8. Настройте onboarding и ATT

Количество слайдов, тексты и media принадлежат приложению. Единственный источник
количества — массив `pages`; отдельное число не передаётся. Минимальная
конфигурация:

```swift
let onboarding = OnboardingConfiguration(
    pages: onboardingPages,
    continueTitle: texts.continueTitle,
    completionTitle: texts.finishTitle,
    progressAccessibilityLabel: texts.progressLabel,
    footerLinks: legalAndRestoreLinks,
    trackingAuthorizationPolicy: .afterFirstSlide()
)
```

Для готовой композиции передайте эту конфигурацию в `BroadOnboardingView`. Если
нужен полностью свой SwiftUI, передайте тот же `OnboardingViewModel` в
`BroadOnboardingFlowHost`: host сохранит переходы, завершение и безопасный ATT,
а приложение нарисует экран само. Подробный пример находится в
[OnboardingAndATT](OnboardingAndATT.md).

Если ATT включён, добавьте локализованный `NSUserTrackingUsageDescription`. Запрос будет выполнен только после фактического появления первого слайда в активном видимом окне.

Rate Us разрешён в settings/main или отдельном app-specific flow. Внутри onboarding не должно быть Rate Us слайда и системного review prompt.

[Точные условия ATT →](OnboardingAndATT.md)

## 9. Соберите AppFlow

Progress и entitlement — разные данные. Progress хранит только монотонные checkpoints onboarding/paywall, а premium всегда приходит из Entitlement Engine.

```swift
let progressRepository = KeyValueAppFlowProgressRepository(
    keyValueStore: stateStore,
    keyPrefix: "my-app.app-flow"
)

let coordinator = AppFlowCoordinator(
    configuration: AppFlowConfiguration(
        onboarding: .enabled,
        initialPaywall: .enabled(allowsClose: true)
    ),
    progressRepository: progressRepository,
    entitlementStatusProvider: entitlementEngine
)
```

После `.purchased` или `.restored` paywall уже передаёт подтверждённый snapshot. Только тогда вызывайте:

```swift
coordinator.subscriptionDidBecomeActive()
```

`pending`, `cancelled`, failure и `completedButUnverified` этот callback не вызывают.

[AppFlow подробно →](AppFlow.md)

## 10. Выберите optional features

### Special offer не нужен

Передайте `nil` и не создавайте экран:

```swift
let specialOfferConfiguration: SpecialOfferConfiguration? = nil
```

Это гарантирует отсутствие placement request, cache, persistence и timer. [Полный контракт](SpecialOffer.md).

### RU billing не нужен

Используйте disabled adapters и не добавляйте `.ruBilling` registration. Не создавайте fake URL или token. [Safe disabled composition](RUBilling.md#safe-disabled-composition).

### RU billing нужен

Eligibility требует host opt-in, `ru_pay = true` из текущего provider-managed
payload и хотя бы один признак iPhone: регион `RU/RUS` **или** первый системный язык с префиксом `ru`. Remote
decision различает absent/enabled/disabled/invalid: отсутствующий, false,
malformed или conflicting флаг выключает RU. Platform-cache/legacy enabled не
авторизует показ RU methods. App Store storefront в этой проверке не участвует.
[Настройка RU billing](RUBilling.md).

Production adapters собирайте через `RUBillingCompositionFactory`: сначала `makeEntitlementRegistration()` добавляется в общий engine, затем `makeServices(refreshEntitlement:operationGate:)` получает уже созданный engine и тот же financial operation gate, что Apple purchase/restore. Это разрывает цикл «RU source нужен engine → RU checkout нужен refresh engine» и не позволяет Apple/RU оплатам идти параллельно.

В enabled dependencies обязательно передайте тот же стабильный app identifier:

```swift
// Keep this instance app-wide across every login/logout composition.
let authorizationSession = SubjectAuthorizationSession()
let authorizationBinding = authorizationSession.begin(for: entitlementSubject)

let ruFactory = RUBillingCompositionFactory(
    configuration: ruConfiguration,
    dependencies: RUBillingCompositionDependencies(
        subject: entitlementSubject,
        applicationIdentifier: AppIdentity.bundleIdentifier,
        authorizationProvider: appSessionAuthorizationProvider,
        authorizationBinding: authorizationBinding,
        cache: platformCache,
        analytics: monetizationAnalytics
    )
)
```

При account switch новый dependency bundle вызывает
`authorizationSession.begin(for:)` на том же app-wide instance: это
отзывает binding всех старых in-flight задач. Logout без нового
bundle обязан вызвать `authorizationSession.invalidate()`.

Он scope-ит один app-wide pending RU record. Запись сохраняет originating subject,
создаётся через atomic insert-if-missing и удаляется только условно по точным
session + attempt. Затем `makeServices` получает `financialOperationGate`/`services.operationGate`,
а не новый instance.

Для enabled RU composition порядок assemblies такой:

```swift
let ruRegistration = ruFactory.makeEntitlementRegistration()
let entitlementEngine = EntitlementEngine(
    registrations: appleAndBackendRegistrations + [ruRegistration],
    subject: entitlementSubject,
    cache: entitlementCache,
    timeoutPolicy: entitlementTimeout
)
let ruServices = ruFactory.makeServices(
    refreshEntitlement: entitlementEngine,
    operationGate: financialOperationGate
)

let assembler = Assembler([
    BroadCoreAssembly(
        bootstrapSteps: bootstrapSteps,
        bootstrapErrorMessages: bootstrapMessages,
        logger: appLogger
    ),
    BroadMonetizationAssembly(
        entitlementEngine: entitlementEngine,
        services: services
    ),
    RUBillingAssembly(services: ruServices),
    BroadUIFlowsAssembly()
])
```

`RUBillingAssembly` должен идти после `BroadMonetizationAssembly`: он заменяет Apple-only `CheckoutSelectedProductUseCaseProtocol` на provider-neutral Apple/RU router. Не добавляйте этот assembly, если RU feature отключена.

Возврат из payment page не запускает polling сам. Host передаёт реальный lifecycle transition в coordinator:

```swift
struct RootScene: View {
    @Environment(\.scenePhase) private var scenePhase

    let paymentReturn: RUPaymentReturnCoordinator
    let appFlowCoordinator: AppFlowCoordinator

    var body: some View {
        AppContent()
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                Task {
                    switch await paymentReturn.applicationDidBecomeActive() {
                    case .active:
                        appFlowCoordinator.subscriptionDidBecomeActive()
                    case .pending:
                        // Остаться без premium и показать app-owned notice.
                        break
                    case let .unavailable(error):
                        // Показать error.userMessage и оставить pending для Retry.
                        showSafeNotice(error.userMessage)
                    case .inactive, .noPendingCheckout:
                        break
                    }
                }
            }
    }
}
```

`paywallLoadTimeout` ограничен диапазоном `1...60` секунд; значение по умолчанию
`12`. Оно покрывает remote request и SDK fallback целиком и не превращает
загрузку paywall в бесконечное ожидание.

Вызов на каждом `.active` безопасен: без pending checkout coordinator вернёт `.noPendingCheckout`, а параллельные callbacks присоединяются к одной polling-операции. Только `.active` открывает premium. `RUPaymentReturnCoordinator` получает тот же `financialOperationGate`: после terminal `.inactive` или `.active` он сам публикует status change, и открытый `PaywallViewModel` пересчитает CTA без повторного `onAppear`.

### Special offer нужен

`ResolveSpecialOfferUseCase` возвращает готовый provider-authorized payload. Не
загружайте placement повторно и не создавайте собственный Adapty REST transport:

```swift
let result = await resolveSpecialOffer(
    configuration: specialOfferConfiguration
)

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

`.eligible` тоже содержит payload, если campaign включена, но duration не задана.
Тогда `presentationAuthorization.expiresAt == nil`, countdown скрыт, а
badge/crossed value/multiplier/period отображаются только при наличии valid remote
полей. Authorization непрозрачно связан с конкретным presentation, поэтому нельзя
перенести remote metadata или timer на другой paywall payload. Ошибка persistence
возвращает `.unavailable(.persistenceUnavailable)` и скрывает offer.

Для timed special offer (`windowDuration`, `cooldownDuration` или persisted timed
state) при сборке `ResolveSpecialOfferUseCase` обязательно передайте
`SpecialOfferClock`, который возвращает только подтверждённое server-synchronized
время. Default `.untrusted` специально скрывает timed offer; никогда не оборачивайте
`Date()` в `.trusted`. Возвращённый server Date сразу связывается с monotonic
instant, поэтому последующий async save не добавляет время. После authorization UI
использует тот же deadline, и изменение системных часов не продлевает countdown. Полный recipe находится в
[Special Offer](SpecialOffer.md).

## 11. Проверьте интеграцию

Перед передачей feature пройдите checklist:

- [ ] package подключён как local dependency, исходники не скопированы в app;
- [ ] assembly идут `Core → Monetization → UIFlows`;
- [ ] bootstrap имеет конечные timeout и не содержит ATT;
- [ ] onboarding не содержит Rate Us/review;
- [ ] каждый app placement имеет явное соответствие, `.main` настроен;
- [ ] UI показывает все provider products в исходном порядке;
- [ ] cached product rehydration не допускает purchase при variation/index/SKU/commercial fingerprint mismatch;
- [ ] consumables либо имеют отдельный durable fulfillment flow, либо generic CTA fail-before-charge;
- [ ] product tap/purchase не меняет opacity/scale/brightness;
- [ ] purchase/restore закрывают flow только после verified active;
- [ ] один app-wide `MonetizationOperationGate` разделяют Apple, restore, RU и все identity compositions;
- [ ] durable Apple store использует production cache, а не in-memory fixture;
- [ ] verified same-bundle purchase listener запущен до Adapty и не вызывает `finish()`;
- [ ] pending Apple recovery вызывается на launch/active; UI не умеет вручную очистить Ask-to-Buy/outcome-unknown;
- [ ] после login запускается customer access recovery; token/RU balance не читается из installation-local storage;
- [ ] token и RU backend используют стабильный app account между переустановками;
- [ ] offline/timeout показывают конечный Retry UI; ambiguous purchase/checkout не повторяется автоматически;
- [ ] special offer `nil` не создаёт никакой работы;
- [ ] presentable special offer передаёт `presentationAuthorization`, persistence fail-closed;
- [ ] timed special offer получает trusted server clock; unavailable/rollback time скрывает offer;
- [ ] RU CTA требует provider-managed `ru_pay = true` и RU region или русский системный язык;
- [ ] real credentials и PII отсутствуют в source/cache/logs/analytics;
- [ ] `./Scripts/lint.sh` и `./Scripts/build.sh` проходят;
- [ ] ручные fixtures на 0, 1, много products и error/pending scenarios пройдены.

Для переноса существующего приложения используйте [Migration Guide](MigrationGuide.md). Карта всех документов находится в [README](../README.md#карта-документации).
