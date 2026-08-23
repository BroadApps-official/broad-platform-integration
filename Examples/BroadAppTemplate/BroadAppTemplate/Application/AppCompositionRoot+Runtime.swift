import BroadCore
import BroadMonetization
import BroadUIFlows
import Swinject

struct CompositionRuntime {
    let assembler: Assembler
    let composition: PlatformComposition
    let monetizationEnvironment: ExampleMonetizationEnvironment
    let specialOfferViewModel: ExampleSpecialOfferFixtureViewModel?
    let logger: any BroadLoggerProtocol
    let cache: ExampleCacheDependencies
}

struct PlatformComposition {
    let progressRepository: any AppFlowProgressRepositoryProtocol
    let appFlowCoordinator: AppFlowCoordinator
    let appFlowSceneViewModel: AppFlowSceneViewModel
    let onboardingViewModel: OnboardingViewModel
    let paywallViewModel: PaywallViewModel
    let rootViewModel: RootViewModel
}

struct PlatformDependencies {
    let coreModule: BroadCoreModule
    let monetizationModule: BroadMonetizationModule
    let uiFlowsModule: BroadUIFlowsModule
    let runAppBootstrapUseCase: any RunAppBootstrapUseCaseProtocol
    let stateStore: any KeyValueStoreProtocol
    let entitlementStatusProvider: any EntitlementStatusProviderProtocol
    let trackingAuthorization: any TrackingAuthorizationUseCaseProtocol
    let loadPaywall: any LoadPaywallUseCaseProtocol
    let selectProduct: any SelectProductUseCaseProtocol
    let checkoutProduct: any CheckoutSelectedProductUseCaseProtocol
    let restorePurchases: any RestorePurchasesUseCaseProtocol

    init(resolver: Resolver) {
        guard
            let coreModule = resolver.resolve(BroadCoreModule.self),
            let monetizationModule = resolver.resolve(BroadMonetizationModule.self),
            let uiFlowsModule = resolver.resolve(BroadUIFlowsModule.self),
            let bootstrap = resolver.resolve(RunAppBootstrapUseCaseProtocol.self),
            let stateStore = resolver.resolve(KeyValueStoreProtocol.self),
            let entitlement = resolver.resolve(EntitlementStatusProviderProtocol.self),
            let tracking = resolver.resolve(TrackingAuthorizationUseCaseProtocol.self),
            let loadPaywall = resolver.resolve(LoadPaywallUseCaseProtocol.self),
            let selectProduct = resolver.resolve(SelectProductUseCaseProtocol.self),
            let checkout = resolver.resolve(CheckoutSelectedProductUseCaseProtocol.self),
            let restore = resolver.resolve(RestorePurchasesUseCaseProtocol.self)
        else {
            preconditionFailure("BroadApps platform assemblies are incomplete")
        }

        self.coreModule = coreModule
        self.monetizationModule = monetizationModule
        self.uiFlowsModule = uiFlowsModule
        runAppBootstrapUseCase = bootstrap
        self.stateStore = stateStore
        entitlementStatusProvider = entitlement
        trackingAuthorization = tracking
        self.loadPaywall = loadPaywall
        self.selectProduct = selectProduct
        checkoutProduct = checkout
        restorePurchases = restore
    }
}

struct ExampleCacheDependencies {
    let repository: any CacheRepositoryProtocol
    let key: CacheKey<ExampleCachedConfiguration>
    let value: ExampleCachedConfiguration

    init(
        configuration: AppConfiguration.CacheFixture,
        logger: any BroadLoggerProtocol
    ) {
        let keyValueStore = UserDefaultsKeyValueStore(
            suiteName: configuration.suiteName,
            namespace: configuration.namespace,
            maximumDataSize: configuration.maximumDataSize
        )
        repository = VersionedJSONCacheRepository(
            keyValueStore: keyValueStore,
            maximumEncodedSize: configuration.maximumDataSize,
            logger: logger
        )
        key = CacheKey(
            name: configuration.keyName,
            schemaIdentifier: configuration.schemaIdentifier,
            version: configuration.version,
            policy: CachePolicy(timeToLive: configuration.timeToLive)
        )
        value = configuration.value
    }
}
