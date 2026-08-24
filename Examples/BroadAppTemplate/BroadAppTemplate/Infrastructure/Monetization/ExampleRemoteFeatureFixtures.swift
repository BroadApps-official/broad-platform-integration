import BroadCore
import BroadMonetization
import Foundation

struct ExamplePaywallRepository: PaywallRepositoryProtocol {
    let arguments: [String]

    func loadPaywall(
        for placementID: PlacementID
    ) async -> PaywallLoadOutcome {
        if arguments.contains("-paywall-failure") {
            return .unavailable(
                .example(
                    message: "Тарифы временно недоступны.",
                    code: "example.paywall.unavailable"
                )
            )
        }

        let scenario = ExampleRemoteFeatureScenario.current(arguments: arguments)
        if scenario == .specialOfferMainFallback,
           placementID == .specialOffer {
            return .unavailable(
                .example(
                    message: "Special Offer fixture использует fallback на main.",
                    code: "example.special-offer.main-fallback"
                )
            )
        }

        return .loaded(makePayload(placementID: placementID, scenario: scenario))
    }
}

private extension ExamplePaywallRepository {
    func makePayload(
        placementID: PlacementID,
        scenario: ExampleRemoteFeatureScenario?
    ) -> PaywallPayload {
        let isHardPaywall = arguments.contains("-paywall-hard")
        return PaywallPayload(
            presentationID: .generated(),
            paywallReference: PaywallReference(
                rawValue: "example-\(placementID.rawValue)-paywall"
            ),
            variationID: PaywallVariationID(
                rawValue: "example-\(placementID.rawValue)-fixture"
            ),
            origin: PaywallOrigin(
                requestedPlacementID: placementID,
                resolvedPlacementID: placementID,
                catalogSource: .adapty
            ),
            products: products(
                count: Self.productCount(arguments: arguments),
                usesRUBillingFixture: arguments.contains("-paywall-payment-methods")
                    || scenario?.isRUPay == true
            ),
            remoteConfiguration: ExampleRemoteFeaturePayloadFactory.configuration(
                scenario: scenario,
                placementID: placementID,
                isHardPaywall: isHardPaywall,
                usesLegacyPaymentFixture: arguments.contains("-paywall-payment-methods")
            ),
            remoteConfigurationProvenance: ExampleRemoteFeaturePayloadFactory.provenance(
                scenario: scenario
            ),
            fetchedAt: Date()
        )
    }

    static func productCount(arguments: [String]) -> Int {
        if arguments.contains("-paywall-empty") {
            return 0
        }
        if arguments.contains("-paywall-one-product") {
            return 1
        }
        if arguments.contains("-paywall-two-products") {
            return 2
        }
        if arguments.contains("-paywall-many-products") {
            return 12
        }
        return 4
    }

    func products(
        count: Int,
        usesRUBillingFixture: Bool
    ) -> [MonetizationProduct] {
        (0 ..< count).map { index in
            let fixture = ExampleProductFixture.all[index % ExampleProductFixture.all.count]
            return MonetizationProduct(
                presentationID: .generated(),
                reference: ProductReference(
                    rawValue: "example-product-reference-\(index)-\(UUID().uuidString)"
                ),
                productID: ProductID(rawValue: fixture.productID),
                kind: fixture.kind,
                title: fixture.title,
                subtitle: fixture.subtitle,
                price: Money(
                    amount: fixture.amount,
                    currencyCode: usesRUBillingFixture ? "RUB" : "USD"
                ),
                displayPrice: usesRUBillingFixture
                    ? fixture.rubleDisplayPrice
                    : fixture.displayPrice,
                subscriptionPeriod: fixture.period,
                catalogSource: .adapty
            )
        }
    }
}

private enum ExampleRemoteFeaturePayloadFactory {
    static func configuration(
        scenario: ExampleRemoteFeatureScenario?,
        placementID: PlacementID,
        isHardPaywall: Bool,
        usesLegacyPaymentFixture: Bool
    ) -> RemotePaywallConfiguration {
        RemotePaywallConfiguration(
            isRUBillingEnabled: usesLegacyPaymentFixture
                || scenario?.isRUPayEnabled == true,
            accessPolicy: isHardPaywall ? .hard : .soft,
            closeDelay: isHardPaywall ? nil : 0,
            uiVariantID: PaywallUIVariantID(rawValue: "example-adaptive"),
            specialOffer: specialOffer(
                scenario: scenario,
                placementID: placementID
            )
        )
    }

    static func provenance(
        scenario: ExampleRemoteFeatureScenario?
    ) -> PaywallRemoteConfigurationProvenance {
        switch scenario {
        case .specialOfferPlatformCache, .ruPayPlatformCache:
            .platformCache
        case .ruPayProviderEnabled:
            .verifiedFreshRemote
        case .specialOfferEnabled,
             .specialOfferDisabled,
             .specialOfferMainFallback,
             .specialOfferLoopingTimer,
             .ruPayProviderDisabled,
             .ruPayAdaptyFallbackRejected:
            .providerCacheFallbackPossible
        case nil:
            .verifiedFreshRemote
        }
    }

    private static func specialOffer(
        scenario: ExampleRemoteFeatureScenario?,
        placementID: PlacementID
    ) -> SpecialOfferRemoteConfiguration? {
        switch scenario {
        case .specialOfferEnabled where placementID == .specialOffer:
            configuration(isEnabled: true)
        case .specialOfferDisabled where placementID == .specialOffer:
            configuration(isEnabled: false)
        case .specialOfferPlatformCache where placementID == .specialOffer:
            configuration(isEnabled: true)
        case .specialOfferMainFallback where placementID == .main:
            configuration(isEnabled: true)
        case .specialOfferLoopingTimer where placementID == .specialOffer:
            configuration(isEnabled: true)
        default:
            nil
        }
    }

    private static func configuration(
        isEnabled: Bool
    ) -> SpecialOfferRemoteConfiguration {
        SpecialOfferRemoteConfiguration(
            isEnabled: isEnabled,
            crossedPrice: "1 990 ₽",
            crossedValue: 1990,
            priceMultiplier: 2,
            periodText: "навсегда",
            badge: "SPECIAL OFFER"
        )
    }
}

struct ExampleProductFixture {
    let productID: String
    let kind: MonetizationProductKind
    let title: String
    let subtitle: String?
    let amount: Decimal
    let displayPrice: String
    let rubleDisplayPrice: String
    let period: SubscriptionPeriod

    static let all = [
        ExampleProductFixture(
            productID: "example.premium.weekly",
            kind: .autoRenewableSubscription,
            title: "Недельная подписка",
            subtitle: "Гибкий доступ",
            amount: 3.99,
            displayPrice: "$3.99",
            rubleDisplayPrice: "299 ₽",
            period: .week()
        ),
        ExampleProductFixture(
            productID: "example.premium.monthly",
            kind: .autoRenewableSubscription,
            title: "Месячная подписка",
            subtitle: "Самый популярный тариф",
            amount: 8.99,
            displayPrice: "$8.99",
            rubleDisplayPrice: "699 ₽",
            period: .month()
        ),
        ExampleProductFixture(
            productID: "example.premium.yearly",
            kind: .autoRenewableSubscription,
            title: "Годовая подписка с намеренно длинным локализованным названием",
            subtitle: "Один платёж за двенадцать месяцев",
            amount: 49.99,
            displayPrice: "$49.99",
            rubleDisplayPrice: "3 990 ₽",
            period: .year()
        ),
        ExampleProductFixture(
            productID: "example.premium.unknown",
            kind: .unknown,
            title: "Доступ, заданный провайдером",
            subtitle: "Продукт без известного периода остаётся видимым",
            amount: 12.49,
            displayPrice: "$12.49",
            rubleDisplayPrice: "999 ₽",
            period: .unknown
        )
    ]
}

actor ExampleSpecialOfferStateRepository: SpecialOfferStateRepositoryProtocol {
    private var states: [PlacementID: SpecialOfferState] = [:]

    func state(
        for configuration: SpecialOfferConfiguration
    ) async -> SpecialOfferStateLoadOutcome {
        .loaded(states[configuration.placementID] ?? .eligible)
    }

    func save(
        _ state: SpecialOfferState,
        for configuration: SpecialOfferConfiguration
    ) async -> Bool {
        states[configuration.placementID] = state
        return true
    }
}

struct ExampleRussianDeviceContextProvider: RUBillingDeviceContextProviderProtocol {
    func currentContext() -> RUBillingDeviceContext {
        RUBillingDeviceContext(
            regionCode: "RU",
            primaryLanguageIdentifier: "ru"
        )
    }
}

struct ExampleRUStorefrontRepository: StorefrontRepositoryProtocol {
    func currentStorefront() async -> StorefrontResolution {
        .available(
            Storefront(
                identifier: "example-ru-storefront",
                countryCode: "RU"
            )
        )
    }
}

struct ExampleRUCatalogRepository: RUCatalogRepositoryProtocol {
    func loadCatalog() async -> RUCatalogLoadOutcome {
        .loaded(
            RUCatalogPayload(
                products: ExampleProductFixture.all.map { fixture in
                    RUCatalogProduct(
                        catalogProductID: RUCatalogProductID(
                            rawValue: fixture.productID
                        ),
                        kind: .subscription,
                        appStoreProductID: ProductID(rawValue: fixture.productID),
                        price: Money(
                            amount: fixture.amount,
                            currencyCode: "RUB"
                        ),
                        displayPrice: fixture.rubleDisplayPrice,
                        subscriptionPeriod: fixture.period,
                        supportedMethods: [.sbp, .card]
                    )
                },
                fetchedAt: Date(timeIntervalSince1970: 1_800_000_000)
            )
        )
    }
}
