import BroadMonetization
import BroadUIFlows
import Foundation

struct AppFlowNotice: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
}

@MainActor
final class AppFlowSceneViewModel: ObservableObject {
    @Published private(set) var legalURL: URL?
    @Published var notice: AppFlowNotice?

    private let coordinator: AppFlowCoordinator
    private let restorePurchases: any RestorePurchasesUseCaseProtocol
    private var restoreTask: Task<Void, Never>?

    init(
        coordinator: AppFlowCoordinator,
        restorePurchases: any RestorePurchasesUseCaseProtocol
    ) {
        self.coordinator = coordinator
        self.restorePurchases = restorePurchases
    }

    deinit {
        restoreTask?.cancel()
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
        coordinator.initialPaywallDismissed()
    }

    func paywallCompleted(
        _ completion: BroadPaywallCompletion
    ) {
        switch completion {
        case .purchased, .restored:
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
}
