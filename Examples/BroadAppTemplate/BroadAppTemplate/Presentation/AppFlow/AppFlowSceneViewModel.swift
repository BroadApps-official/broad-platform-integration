import BroadCore
import BroadMonetization
import BroadUIFlows
import Combine
import Foundation

struct AppFlowNotice: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
}

@MainActor
final class AppFlowSceneViewModel: ObservableObject {
    @Published private(set) var legalURL: URL?
    @Published private(set) var activeSpecialOfferViewModel: ExampleSpecialOfferFixtureViewModel?
    @Published private(set) var isResolvingSpecialOffer = false
    @Published var notice: AppFlowNotice?

    private let coordinator: AppFlowCoordinator
    private let restorePurchases: any RestorePurchasesUseCaseProtocol
    private let specialOfferViewModel: ExampleSpecialOfferFixtureViewModel?
    private let logger: any BroadLoggerProtocol
    private var restoreTask: Task<Void, Never>?
    private var specialOfferTask: Task<Void, Never>?
    private var routeObservation: AnyCancellable?
    private var lastLoggedRoute: AppFlowRoute

    init(
        coordinator: AppFlowCoordinator,
        restorePurchases: any RestorePurchasesUseCaseProtocol,
        specialOfferViewModel: ExampleSpecialOfferFixtureViewModel?,
        logger: any BroadLoggerProtocol = NoOpBroadLogger()
    ) {
        self.coordinator = coordinator
        self.restorePurchases = restorePurchases
        self.specialOfferViewModel = specialOfferViewModel
        self.logger = logger
        lastLoggedRoute = coordinator.route
        observeRoutes()
    }

    deinit {
        restoreTask?.cancel()
        specialOfferTask?.cancel()
    }

    func onboardingCompleted() {
        coordinator.onboardingCompleted()
    }

    func onboardingFooterAction(
        _ destination: OnboardingFooterDestination
    ) {
        switch destination {
        case .privacyPolicy:
            legalURL = AppConfiguration.privacyPolicyURL
        case .termsOfUse:
            legalURL = AppConfiguration.termsOfUseURL
        case .restorePurchases:
            restoreFromOnboarding()
        }
    }

    func closeLegalPage() {
        legalURL = nil
    }

    func paywallClosed() {
        guard specialOfferTask == nil else {
            return
        }
        guard let specialOfferViewModel else {
            coordinator.initialPaywallDismissed()
            return
        }

        isResolvingSpecialOffer = true
        specialOfferTask = Task { @MainActor [weak self, specialOfferViewModel] in
            let shouldPresent = await specialOfferViewModel.resolveIfNeeded()
            guard let self, !Task.isCancelled else {
                return
            }

            specialOfferTask = nil
            isResolvingSpecialOffer = false
            if shouldPresent {
                activeSpecialOfferViewModel = specialOfferViewModel
                logger.log(
                    .flowAdvanced(
                        source: .initialPaywall,
                        destination: .specialOffer
                    )
                )
            } else {
                coordinator.initialPaywallDismissed()
            }
        }
    }

    func specialOfferClosed() {
        guard activeSpecialOfferViewModel != nil else {
            return
        }

        activeSpecialOfferViewModel = nil
        coordinator.initialPaywallDismissed()
        logger.log(.flowAdvanced(source: .specialOffer, destination: .main))
    }

    func paywallCompleted(
        _ completion: BroadPaywallCompletion
    ) {
        switch completion {
        case .purchased, .restored:
            specialOfferViewModel?.confirmedPurchaseOrRestore()
            activeSpecialOfferViewModel = nil
            coordinator.subscriptionDidBecomeActive()
        }
    }

    private func restoreFromOnboarding() {
        guard restoreTask == nil else {
            return
        }

        let useCase = restorePurchases
        restoreTask = Task { @MainActor [weak self, useCase] in
            let outcome = await useCase()
            guard let self, !Task.isCancelled else {
                return
            }

            restoreTask = nil
            applyRestoreOutcome(outcome)
        }
    }

    private func applyRestoreOutcome(
        _ outcome: RestoreOutcome
    ) {
        switch outcome {
        case .restored:
            specialOfferViewModel?.confirmedPurchaseOrRestore()
            coordinator.subscriptionDidBecomeActive()
            notice = AppFlowNotice(
                title: "Покупка восстановлена",
                message: "Доступ подтверждён. Завершите онбординг, чтобы открыть основной экран."
            )
        case .nothingFound:
            notice = AppFlowNotice(
                title: "Восстанавливать нечего",
                message: "Подтверждённых покупок не найдено."
            )
        case let .unavailable(error), let .failed(error):
            notice = AppFlowNotice(
                title: "Восстановление недоступно",
                message: error.userMessage
            )
        }
    }

    private func observeRoutes() {
        routeObservation = coordinator.$route
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] route in
                self?.recordRouteTransition(to: route)
            }
    }

    private func recordRouteTransition(
        to route: AppFlowRoute
    ) {
        defer { lastLoggedRoute = route }
        guard lastLoggedRoute != route else {
            return
        }
        logger.log(
            .flowAdvanced(
                source: lastLoggedRoute.logStage,
                destination: route.logStage
            )
        )
    }
}

private extension AppFlowRoute {
    var logStage: BroadLogFlowStage {
        switch self {
        case .launch: .launch
        case .onboarding: .onboarding
        case .initialPaywall: .initialPaywall
        case .main: .main
        @unknown default: .launch
        }
    }
}
