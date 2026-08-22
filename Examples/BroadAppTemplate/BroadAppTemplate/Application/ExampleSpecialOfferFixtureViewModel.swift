import BroadCore
import BroadMonetization
import BroadUIFlows
import Combine

@MainActor
final class ExampleSpecialOfferFixtureViewModel: ObservableObject {
    @Published private(set) var paywallViewModel: PaywallViewModel?
    @Published private(set) var statusTitle = "Проверяем Special Offer"
    @Published private(set) var statusMessage = "Загружаем fixture без настоящей покупки…"
    @Published private(set) var isLoading = true

    let scenario: ExampleRemoteFeatureScenario

    private let resolver: any ResolveSpecialOfferUseCaseProtocol
    private let configuration: SpecialOfferConfiguration
    private let paywallDependencies: PaywallViewModelDependencies
    private let logger: any BroadLoggerProtocol
    private var hasLoaded = false

    init(
        scenario: ExampleRemoteFeatureScenario,
        resolver: any ResolveSpecialOfferUseCaseProtocol,
        configuration: SpecialOfferConfiguration,
        paywallDependencies: PaywallViewModelDependencies,
        logger: any BroadLoggerProtocol
    ) {
        self.scenario = scenario
        self.resolver = resolver
        self.configuration = configuration
        self.paywallDependencies = paywallDependencies
        self.logger = logger
    }

    func loadIfNeeded() async {
        guard !hasLoaded else {
            return
        }
        hasLoaded = true

        let resolution = await resolver(configuration: configuration)
        guard let paywall = resolution.paywall,
              let authorization = resolution.presentationAuthorization
        else {
            isLoading = false
            statusTitle = "Special Offer не открылся"
            statusMessage = Self.explanation(for: resolution.state)
            logResult(scenario: scenario, state: resolution.state, paywall: nil)
            return
        }

        paywallViewModel = makePaywallViewModel(
            paywall: paywall,
            authorization: authorization
        )
        isLoading = false
        logResult(scenario: scenario, state: resolution.state, paywall: paywall)
    }
}

private extension ExampleSpecialOfferFixtureViewModel {
    func makePaywallViewModel(
        paywall: PaywallPayload,
        authorization: SpecialOfferPresentationAuthorization
    ) -> PaywallViewModel {
        PaywallViewModel(
            configuration: BroadPaywallConfiguration(
                placementID: configuration.placementID,
                defaultSelection: .index(0),
                access: BroadPaywallAccessConfiguration(defaultPolicy: .soft),
                copy: .russian,
                legalLinks: [
                    BroadPaywallLegalLink(
                        id: "terms",
                        title: "Условия",
                        url: AppConfiguration.termsOfUseURL
                    ),
                    BroadPaywallLegalLink(
                        id: "privacy",
                        title: "Политика",
                        url: AppConfiguration.privacyPolicyURL
                    )
                ],
                specialOfferCopy: .russian,
                specialOfferAuthorization: authorization
            ),
            dependencies: paywallDependencies,
            initialPayload: paywall
        )
    }

    static func explanation(for state: SpecialOfferState) -> String {
        switch state {
        case let .unavailable(reason):
            "Ожидаемое безопасное состояние: \(reason.rawValue). Пейвол кампании не показан."
        case .eligible, .active:
            "Кампания разрешена, но payload для показа отсутствует."
        case .expired:
            "Время кампании закончилось."
        case .cooldown:
            "Кампания находится на паузе между показами."
        }
    }

    func logResult(
        scenario: ExampleRemoteFeatureScenario,
        state: SpecialOfferState,
        paywall: PaywallPayload?
    ) {
        logger.log(
            .remoteFeatureFixtureEvaluated(
                scenario: scenario.rawValue,
                state: String(describing: state),
                requestedPlacement: paywall?.origin.requestedPlacementID.rawValue,
                resolvedPlacement: paywall?.origin.resolvedPlacementID.rawValue,
                variation: paywall?.variationID?.rawValue,
                provenance: paywall?.remoteConfigurationProvenance.rawValue
            )
        )
    }
}
