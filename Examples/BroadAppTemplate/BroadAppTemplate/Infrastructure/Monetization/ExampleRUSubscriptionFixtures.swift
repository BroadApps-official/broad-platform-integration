import BroadCore
import BroadMonetization
import Foundation

actor ExampleRUSubscriptionState {
    private var isCancelled: Bool

    init(isCancelled: Bool) {
        self.isCancelled = isCancelled
    }

    func status() -> RUSubscriptionManagementStatus {
        RUSubscriptionManagementStatus(
            subscriptionID: RUSubscriptionID(rawValue: "fixture-subscription"),
            planName: "Премиум на месяц",
            isActive: true,
            expiresAt: Calendar.current.date(
                byAdding: .day,
                value: 18,
                to: Date()
            ),
            isLifetime: false,
            isAutoRenewalCancelled: isCancelled
        )
    }

    func cancel() -> Date? {
        isCancelled = true
        return Calendar.current.date(byAdding: .day, value: 18, to: Date())
    }
}

struct ExampleLoadRUSubscriptionStatusUseCase:
    LoadRUSubscriptionStatusUseCaseProtocol {
    let state: ExampleRUSubscriptionState

    func callAsFunction() async -> RUSubscriptionManagementLoadOutcome {
        await .loaded(state.status())
    }
}

struct ExampleCancelRUSubscriptionUseCase:
    CancelRUSubscriptionUseCaseProtocol {
    let state: ExampleRUSubscriptionState

    func callAsFunction(
        subscriptionID: RUSubscriptionID
    ) async -> RUSubscriptionCancellationOutcome {
        guard subscriptionID.rawValue == "fixture-subscription" else {
            return .unavailable(
                AppError(
                    kind: .unavailable,
                    userMessage: "Подписка не найдена.",
                    diagnosticCode: "example.ru-subscription.not-found",
                    isRetryable: false
                )
            )
        }
        return await .cancelled(effectiveUntil: state.cancel())
    }
}
