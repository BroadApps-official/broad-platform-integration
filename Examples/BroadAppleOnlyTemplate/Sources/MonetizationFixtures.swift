import BroadCore
import BroadMonetization
import BroadUIFlows
import SwiftUI

@MainActor
struct FixturePaywallScreen: View {
    @StateObject private var viewModel: PaywallViewModel

    init(showsSpecialOffer: Bool) {
        let payload = FixtureCatalog.subscriptionPayload(
            placementID: showsSpecialOffer ? .specialOffer : .main,
            showsSpecialOffer: showsSpecialOffer
        )
        let authorization: SpecialOfferPresentationAuthorization? = if showsSpecialOffer {
            FixtureCatalog.specialOfferAuthorization(for: payload)
        } else {
            nil
        }
        let operationGate = MonetizationOperationGate()
        let dependencies = PaywallViewModelDependencies(
            loadPaywall: FixturePaywallLoader(payload: payload),
            selectProduct: FixtureProductSelector(),
            checkoutProduct: FixtureCheckout(),
            restorePurchases: FixtureRestore(),
            resolveCheckoutMethods: FixtureCheckoutMethods(),
            trackEvent: FixturePaywallTracker(),
            presentationLifecycle: NoOpPaywallPresentationLifecycle(),
            operationGate: operationGate
        )
        _viewModel = StateObject(
            wrappedValue: PaywallViewModel(
                configuration: BroadPaywallConfiguration(
                    placementID: payload.origin.requestedPlacementID,
                    specialOfferAuthorization: authorization
                ),
                dependencies: dependencies,
                initialPayload: payload
            )
        )
    }

    var body: some View {
        BroadPaywallView(
            viewModel: viewModel,
            onClose: {},
            onCompleted: { _ in }
        )
        .navigationBarBackButtonHidden(false)
    }
}

@MainActor
struct FixtureTokenPaywallScreen: View {
    @StateObject private var viewModel: BroadTokenPaywallViewModel

    init() {
        let payload = FixtureCatalog.tokenPayload()
        let operationGate = MonetizationOperationGate()
        let purchaseManager = TokenPurchaseManager(
            purchaseRepository: FixturePurchaseRepository(),
            evidenceProvider: FixtureTokenEvidenceProvider(),
            fulfillmentRepository: FixtureTokenFulfillmentRepository(),
            pendingStore: FixturePendingTokenStore(),
            operationGate: operationGate
        )
        _viewModel = StateObject(
            wrappedValue: BroadTokenPaywallViewModel(
                configuration: BroadTokenPaywallConfiguration(copy: .russian),
                dependencies: BroadTokenPaywallViewModelDependencies(
                    loadPaywall: FixturePaywallLoader(payload: payload),
                    selectProduct: FixtureProductSelector(),
                    purchaseManager: purchaseManager,
                    recoverTokenAccount: FixtureTokenAccountRecovery(),
                    onBalanceConfirmed: { _ in },
                    trackEvent: FixturePaywallTracker()
                )
            )
        )
    }

    var body: some View {
        BroadTokenPaywallView(
            viewModel: viewModel,
            theme: .standard,
            onClose: {}
        )
    }
}

enum FixtureCatalog {
    static func specialOfferAuthorization(
        for offerPayload: PaywallPayload
    ) -> SpecialOfferPresentationAuthorization? {
        let now = Date()
        guard case let .synchronized(trustedTime) = SpecialOfferClockReading.trusted(now) else {
            return nil
        }
        let gatePayload = subscriptionPayload(
            placementID: .main,
            showsSpecialOffer: true
        )
        return SpecialOfferResolution(
            state: .active(
                SpecialOfferWindow(
                    startedAt: now,
                    expiresAt: now.addingTimeInterval(
                        SpecialOfferConfiguration.standardWindowDuration
                    )
                )
            ),
            paywall: offerPayload,
            trustedTime: trustedTime,
            gatePaywall: gatePayload
        )
        .presentationAuthorization
    }

    static func subscriptionPayload(
        placementID: PlacementID,
        showsSpecialOffer: Bool
    ) -> PaywallPayload {
        let products = [
            MonetizationProduct(
                presentationID: .generated(),
                reference: ProductReference(rawValue: "fixture-subscription-occurrence-a"),
                productID: ProductID(rawValue: "fixture-subscription-a"),
                kind: .autoRenewableSubscription,
                title: "Monthly fixture",
                subtitle: "Provider order: first occurrence",
                price: Money(amount: 199, currencyCode: "RUB"),
                displayPrice: "provider display value A",
                subscriptionPeriod: .month(),
                catalogSource: .adapty
            ),
            MonetizationProduct(
                presentationID: .generated(),
                reference: ProductReference(rawValue: "fixture-subscription-occurrence-b"),
                productID: ProductID(rawValue: "fixture-subscription-b"),
                kind: .autoRenewableSubscription,
                title: "Yearly fixture",
                subtitle: "Provider order: second occurrence",
                price: Money(amount: 1490, currencyCode: "RUB"),
                displayPrice: "provider display value B",
                subscriptionPeriod: .year(),
                catalogSource: .adapty
            )
        ]
        let remoteConfiguration = RemotePaywallConfiguration(
            specialOffer: showsSpecialOffer
                ? SpecialOfferRemoteConfiguration(
                    isEnabled: true,
                    crossedPrice: "provider crossed value",
                    priceMultiplier: 2,
                    periodText: "Fixture active window",
                    badge: "SPECIAL OFFER"
                )
                : nil
        )
        return PaywallPayload(
            presentationID: .generated(),
            paywallReference: PaywallReference(rawValue: "fixture-subscription-paywall"),
            origin: PaywallOrigin(
                requestedPlacementID: placementID,
                resolvedPlacementID: placementID,
                catalogSource: .adapty
            ),
            products: products,
            remoteConfiguration: remoteConfiguration,
            remoteConfigurationProvenance: .providerCacheFallbackPossible,
            fetchedAt: Date()
        )
    }

    static func tokenPayload() -> PaywallPayload {
        PaywallPayload(
            presentationID: .generated(),
            paywallReference: PaywallReference(rawValue: "fixture-token-paywall"),
            origin: PaywallOrigin(
                requestedPlacementID: .tokens,
                resolvedPlacementID: .tokens,
                catalogSource: .adapty
            ),
            products: [
                MonetizationProduct(
                    presentationID: .generated(),
                    reference: ProductReference(rawValue: "fixture-token-occurrence"),
                    productID: ProductID(rawValue: "fixture-token-product"),
                    kind: .consumable,
                    title: "100 fixture tokens",
                    price: Money(amount: 99, currencyCode: "RUB"),
                    displayPrice: "provider token value",
                    catalogSource: .adapty
                )
            ],
            fetchedAt: Date()
        )
    }
}

struct FixturePaywallLoader: LoadPaywallUseCaseProtocol {
    let payload: PaywallPayload

    func callAsFunction(_: PaywallLoadRequest) async -> PaywallLoadOutcome {
        .loaded(payload)
    }
}

struct FixtureProductSelector: SelectProductUseCaseProtocol {
    func callAsFunction(
        productPresentationID: ProductPresentationID,
        in paywall: PaywallPayload
    ) -> ProductSelection? {
        guard let product = paywall.products.first(where: {
            $0.presentationID == productPresentationID
        }) else {
            return nil
        }
        return ProductSelection(paywall: paywall, product: product)
    }
}

struct FixtureCheckout: CheckoutSelectedProductUseCaseProtocol {
    func callAsFunction(
        _: ProductSelection,
        using _: CheckoutMethod,
        remoteConfiguration _: RemotePaywallConfiguration,
        options _: CheckoutOptions
    ) async -> CheckoutSelectedProductOutcome {
        .cancelled
    }
}

struct FixtureRestore: RestorePurchasesUseCaseProtocol {
    func callAsFunction() async -> RestoreOutcome {
        .nothingFound
    }
}

struct FixtureCheckoutMethods: ResolveCheckoutMethodsUseCaseProtocol {
    func callAsFunction(
        for _: MonetizationProduct,
        remoteConfiguration _: RemotePaywallConfiguration
    ) async -> CheckoutMethodsResolution {
        CheckoutMethodsResolution(methods: [.apple], storefront: nil)
    }
}

struct FixturePaywallTracker: TrackPaywallEventUseCaseProtocol {
    func callAsFunction(_: MonetizationAnalyticsEvent) async {}
}

struct FixturePurchaseRepository: PurchaseRepositoryProtocol {
    func purchase(_: PurchaseRequest) async -> PurchaseAttemptOutcome {
        .cancelled
    }
}

struct FixtureTokenEvidenceProvider: TokenTransactionEvidenceProviderProtocol {
    func evidence(
        productID _: ProductID,
        purchasedAfter _: Date
    ) async -> TokenEvidenceResolution {
        .notFound
    }
}

struct FixtureTokenFulfillmentRepository: TokenFulfillmentRepositoryProtocol {
    func fulfill(_: TokenFulfillmentRequest) async -> TokenFulfillmentOutcome {
        .pending
    }
}

actor FixturePendingTokenStore: PendingTokenPurchaseStoreProtocol {
    nonisolated let pendingOperationBlockerKey = PendingOperationBlockerKey(
        kind: .tokenPurchase,
        applicationIdentifier: "broad-ui-flows-gallery"
    )

    func begin(context _: PurchaseAnalyticsContext) async -> Bool {
        false
    }

    func state() async -> PendingTokenPurchaseState {
        .none
    }

    func save(
        evidence _: TokenTransactionEvidence,
        attemptID _: MonetizationAttemptID
    ) async -> Bool {
        false
    }

    func clear(attemptID _: MonetizationAttemptID) async -> Bool {
        true
    }
}

struct FixtureTokenAccountRecovery: RecoverTokenAccountUseCaseProtocol {
    func callAsFunction() async -> TokenAccountRecoveryOutcome {
        .restored(TokenBalanceSnapshot(balance: 250, updatedAt: Date()))
    }
}
