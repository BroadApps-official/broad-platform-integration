# Архитектура

BroadApps iOS Platform разделена на три публичных модуля с однонаправленными зависимостями.

```text
Host App → BroadUIFlows
BroadUIFlows → BroadMonetization
BroadUIFlows → BroadCore
BroadMonetization → BroadCore
```

## BroadCore

Shared contracts and primitives: bootstrap, cache, loadable state, retry, timeout, logging and ATT boundaries.

It must not depend on `BroadMonetization` or `BroadUIFlows`.

The implemented Bootstrap Engine is an actor. Host applications inject immutable, `Sendable` steps before Swinject builds the object graph. Critical steps form the route gate; background steps start only after that gate opens.

The cache slice keeps Domain contracts separate from storage details. `CacheRepositoryProtocol` and typed cache models form the public boundary. `VersionedJSONCacheRepository` owns envelope encoding and freshness rules. `UserDefaultsKeyValueStore` is an actor-isolated Infrastructure adapter for small snapshots; a future file adapter can conform to the same `KeyValueStoreProtocol` without changing feature code.

Persistent app-flow progress uses the lower-level `KeyValueStoreProtocol`, but it is not cache data. `BroadCoreAssembly` registers a separate state store with the default namespace `com.broadapps.platform.state`; the cache keeps its own `com.broadapps.platform.cache` namespace and freshness semantics. The host may inject either store independently. Flow checkpoints therefore have no TTL, stale fallback or cache eviction policy.

The logging slice exposes only `BroadLoggerProtocol` and a closed `BroadLogEvent` model. `OSLogBroadLogger` is the single Infrastructure adapter allowed to import `OSLog`; `NoOpBroadLogger` is the safe default. Bootstrap and cache emit only typed enums and counters, never host strings, payloads, keys or raw SDK errors.

`LoadableState<Value>` is a shared actor-neutral state value with no SwiftUI, Combine, DI or task ownership. It preserves previously rendered content during refresh/error when the feature allows that behavior. It does not replace domain-specific contracts: `AppBootstrapState` remains the bootstrap-engine lifecycle, and `CacheReadResult` remains the storage-freshness result. A ViewModel/Application mapper converts those results into `LoadableState`.

## BroadMonetization

Монетизация: typed placements, Adapty paywalls/products и provider-owned
variation attribution, remote config, purchase/restore, Entitlement Engine,
Apple/основной backend/RU billing и analytics.

Only this module may link Adapty. Its Domain layer must not expose SDK models.

Entitlement Engine и Apple source разделены по слоям:

- Domain содержит actor-neutral модели, три логических source (`apple`, `primaryBackend`, `ruBilling`), freshness-policy, `AppleEntitlementVerifierProtocol`, append-only `ApplePremiumProductCatalog` и чистый `EntitlementAggregator`.
- Application actor `EntitlementEngine` параллельно запускает source repositories под общим конечным deadline; `AppleEntitlementSourceFactory` собирает один StoreKit-backed `.apple` registration.
- Data содержит composite `AppleEntitlementRepository` и actor `VersionedEntitlementCache`. Adapty и StoreKit остаются verifier-ами одной logical authority, поэтому cache получает ровно один assertion `apple + subject`.
- Infrastructure изолирует реальные StoreKit transaction records и Adapty profile snapshots. `AdaptyProfile`, `Transaction` и raw SDK errors не выходят в Domain/Data/UI.
- DI регистрирует один engine как `EntitlementRepositoryProtocol`, `RefreshEntitlementUseCaseProtocol` и минимальный `EntitlementStatusProviderProtocol` для AppFlow.

Любой пригодный `active` даёт общий `active`. Общий `inactive` возможен только тогда, когда каждый настроенный источник имеет пригодный явный `inactive`. Timeout, SDK/HTTP error, отсутствие авторизации и unverified transaction дают `unresolved`; для AppFlow он маппится в `unknown`.

Кеш имеет конечный TTL. После TTL только ранее подтверждённый `active` может временно жить внутри отдельного конечного offline grace; `inactive` grace не получает. Subject либо anonymous, либо представлен непрозрачным 32-byte fingerprint, поэтому raw user ID и email не попадают в storage key. Поздний ответ после timeout не пишет cache от имени завершённого refresh.

StoreKit `currentEntitlements` проверяет exact app bundle, product type и полный каталог текущих/исторических premium SKU. Публичный Adapty 3.17.3 client помечает profile как `unqualified`, потому что SDK скрывает cache fallback; fresh `active/inactive` возможны только через дополнительно переданный server-validated client.

Production adapters основного backend и RU billing изолируют subject-bound authorization, HTTPS transport и wire contracts. `AdaptyPaywallRepository` сохраняет каждый provider product 1:1, включая одинаковые SKU и любое количество элементов. `LoadPaywallUseCase` использует requested placement/cache, затем общий fallback `.main`/его cache. Purchase и restore запускают новую entitlement generation; только подтверждённый `active` возвращает `.activated/.restored`. Optional special offer при `nil` не обращается ни к placement, ни к cache/timer/UI. `UnknownEntitlementStatusProvider` остаётся безопасным default для host, который не собрал engine. Подробности: [Monetization](Monetization.md) и [Entitlements](Entitlements.md).

Financial application boundary дополнительно содержит один process-wide
`MonetizationOperationGate`, app-wide subject-aware Apple/RU pending records и
StoreKit transaction recovery. Cached Adapty handle rehydrate-ится только при
exact variation/index/SKU/commercial-fingerprint match; generic consumable
purchase fail-before-charge требует отдельного host fulfillment layer. Provider
presentation lifecycle отделён от best-effort analytics и передаётся в UI вместе
с `TrackPaywallEventUseCaseProtocol`.

## BroadUIFlows

Reusable SwiftUI flows: loader, onboarding, adaptive paywall and common loading/error/retry states.

Views receive prepared dependencies through `init`. They do not resolve services or create repositories and use cases.

The implemented loadable UI slice keeps `BroadLoadableView` as an exhaustive renderer over `LoadableState`: refresh/stale reuse one content branch, while blocking `error(previousValue:)` delegates any previous-value decision explicitly to the host. Concrete loader, refresh, empty, error and stale surfaces accept app content and `BroadLoadableTheme`; they own no `Task`, timeout, SDK or DI. See [Loadable UI](LoadableUI.md).

The implemented AppFlow slice has three distinct responsibilities:

- `AppFlowStateMachine` is a pure value type that resolves `launch`, `onboarding`, `initialPaywall` and `main` from configuration, stored progress and a typed entitlement status.
- `KeyValueAppFlowProgressRepository` persists versioned, monotonic onboarding/paywall markers through the separate Core state store. It never persists entitlement.
- `AppFlowCoordinator` is a `@MainActor` application object that owns async transitions and stale-task protection. `BroadAppFlowView` is a generic, state-only root renderer; it creates no task and knows nothing about storage, SDKs or Swinject.

The configurable onboarding slice receives stable page IDs, app-owned copy, media descriptors and legal/restore footer links. `OnboardingViewModel` owns the ATT timing policy: the first page must actually be visible, the scene active and a visible window attached before its cancellable delay starts. The native SDK remains inside the Core adapter. See [Onboarding and ATT](OnboardingAndATT.md).

The host starts AppFlow only after bootstrap reaches `ready` or `degraded`. A verified active entitlement skips the initial paywall. `unknown` is not converted to `inactive`: terminal uncertainty opens the free main route, grants no premium and does not persist the paywall checkpoint. Once the current session reaches `main`, late inactive results do not push it backwards. A verified activation received during onboarding is remembered for the session, but onboarding still finishes before the route advances. See [AppFlow](AppFlow.md).

## Composition root

The host app owns the composition root. Swinject assemblies are applied in dependency order:

1. `BroadCoreAssembly`
2. `BroadMonetizationAssembly`
3. `BroadUIFlowsAssembly`
4. Host-app repositories, use cases and view models

`BroadCoreAssembly` registers the module descriptor plus container-scoped bootstrap, cache, state-store and logging contracts. The host can inject a prebuilt cache repository and a separate `KeyValueStoreProtocol` for durable platform state, or use their isolated UserDefaults defaults. It can inject one prebuilt logger or keep the `NoOpBroadLogger` default. A custom cache repository must receive that logger when the host constructs it. The host also supplies its prebuilt bootstrap steps; neither Swinject `Resolver` nor `Container` crosses into an async operation.

`BroadMonetizationAssembly(entitlementEngine:services:)` регистрирует готовый engine и optional monetization services. Более низкоуровневый initializer позволяет передать отдельный `EntitlementStatusProviderProtocol`; safe default возвращает `unknown`. `BroadUIFlowsAssembly` регистрирует descriptor модуля. Затем `@MainActor` composition root создаёт `KeyValueAppFlowProgressRepository`, `AppFlowCoordinator`, onboarding/paywall ViewModel и передаёт их в root View. Views никогда не вызывают `resolve`.

См. [Bootstrap](Bootstrap.md), [Cache and offline](CachingAndOffline.md), [Monetization](Monetization.md), [Entitlements](Entitlements.md), [Logging](Logging.md), [Loadable state](LoadableState.md), [AppFlow](AppFlow.md) и формальное решение [ADR-0001](ADR/0001-module-boundaries.md).
