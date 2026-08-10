import BroadCore
import BroadMonetization
import Foundation

public enum BroadRUSubscriptionManagementViewState: Equatable, Sendable {
    case idle
    case loading
    case loaded(RUSubscriptionManagementStatus)
    case failed(AppError)
}

public struct BroadRUSubscriptionDependencies: Sendable {
    let loadStatus: any LoadRUSubscriptionStatusUseCaseProtocol
    let cancelSubscription: any CancelRUSubscriptionUseCaseProtocol

    public init(
        loadStatus: any LoadRUSubscriptionStatusUseCaseProtocol,
        cancelSubscription: any CancelRUSubscriptionUseCaseProtocol
    ) {
        self.loadStatus = loadStatus
        self.cancelSubscription = cancelSubscription
    }
}

@MainActor
public final class BroadRUSubscriptionManagementViewModel: ObservableObject {
    @Published public private(set) var state:
        BroadRUSubscriptionManagementViewState = .idle
    @Published public private(set) var isCancelling = false
    @Published public private(set) var cancellationError: AppError?

    private let dependencies: BroadRUSubscriptionDependencies
    private var loadTask: Task<Void, Never>?
    private var cancelTask: Task<Void, Never>?

    public init(dependencies: BroadRUSubscriptionDependencies) {
        self.dependencies = dependencies
    }

    deinit {
        loadTask?.cancel()
        cancelTask?.cancel()
    }

    public func loadIfNeeded() {
        guard case .idle = state else {
            return
        }
        reload()
    }

    public func reload() {
        guard loadTask == nil, !isCancelling else {
            return
        }
        state = .loading
        cancellationError = nil
        let useCase = dependencies.loadStatus
        loadTask = Task { @MainActor [weak self, useCase] in
            let outcome = await useCase()
            guard let self, !Task.isCancelled else {
                return
            }
            loadTask = nil
            switch outcome {
            case let .loaded(status):
                state = .loaded(status)
            case let .unavailable(error):
                state = .failed(error)
            }
        }
    }

    public func cancelSubscription() {
        guard case let .loaded(status) = state,
              status.isActive,
              !status.isAutoRenewalCancelled,
              let subscriptionID = status.subscriptionID,
              cancelTask == nil
        else {
            return
        }

        isCancelling = true
        cancellationError = nil
        let useCase = dependencies.cancelSubscription
        cancelTask = Task { @MainActor [weak self, useCase] in
            let outcome = await useCase(subscriptionID: subscriptionID)
            guard let self, !Task.isCancelled else {
                return
            }
            cancelTask = nil
            isCancelling = false
            applyCancellation(outcome, previousStatus: status)
        }
    }

    private func applyCancellation(
        _ outcome: RUSubscriptionCancellationOutcome,
        previousStatus: RUSubscriptionManagementStatus
    ) {
        switch outcome {
        case let .cancelled(effectiveUntil):
            state = .loaded(
                RUSubscriptionManagementStatus(
                    subscriptionID: previousStatus.subscriptionID,
                    planName: previousStatus.planName,
                    isActive: effectiveUntil.map { $0 > Date() } ?? false,
                    expiresAt: effectiveUntil ?? previousStatus.expiresAt,
                    isLifetime: false,
                    isAutoRenewalCancelled: true
                )
            )
        case .alreadyInactive:
            state = .loaded(
                RUSubscriptionManagementStatus(
                    subscriptionID: previousStatus.subscriptionID,
                    planName: previousStatus.planName,
                    isActive: false,
                    expiresAt: previousStatus.expiresAt,
                    isLifetime: false,
                    isAutoRenewalCancelled: true
                )
            )
        case let .unavailable(error), let .failed(error):
            cancellationError = error
        }
    }
}
